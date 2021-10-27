# frozen_string_literal: true

###############################################################################
# Copyright (c) 2020, Lawrence Livermore National Security, LLC
# Produced at the Lawrence Livermore National Laboratory
# Written by Thomas Mendoza mendoza33@llnl.gov
# LLNL-CODE-801838
# All rights reserved
#
# This file is part of Remote Mirror Security:
# https://github.com/LLNL/remote-mirror-security
#
# SPDX-License-Identifier: MIT
###############################################################################

module SecureMirror
  # defines the GitHub mirror client
  class GitHubMirrorClient < MirrorClient
    MIRROR_ERROR_MAP = {
      Octokit::Unauthorized => SecureMirror::ClientUnauthorized,
      Octokit::Forbidden => SecureMirror::ClientForbidden,
      Octokit::NotFound => SecureMirror::ClientNotFound,
      Octokit::UnprocessableEntity => SecureMirror::ClientGenericError,
      Octokit::ServerError => SecureMirror::ClientServerError
    }.freeze

    ORG_MEMBER_ERROR = 'Could not query GitHub org members: %<msg>s'
    COLLABORATOR_ERROR = 'Could not query GitHub collaborators for repo %<repo>s: %<msg>s'
    BRANCH_ERROR = 'Could not get branch info from GitHub %<repo>s and sha %<sha>s: %<msg>s'
    COMMIT_ERROR = 'Could not get GitHub commit for repo %<repo>s and sha %<sha>s: %<msg>s'
    COMMENT_ERROR = 'Could not get GitHub issue comments for repo %<repo>s, %<sha>s: %<msg>s'
    PREVIEW_HEADER = Octokit::Preview::PREVIEW_TYPES[:commit_pulls]

    attr_reader :config
    def initialize(token, alt_tokens: [], config: nil, client: nil)
      @config = config
      @client = client || Octokit::Client.new(auto_paginate: true, access_token: token)
      @alt_clients = {}
      alt_tokens.each do |name, alt_token|
        @alt_clients[name] = Octokit::Client.new(
          auto_paginate: true,
          access_token: alt_token
        )
      end
    end

    def org_members(org: @config[:trusted_org], client_name: '')
      wrap_with_github_error_handler(template: ORG_MEMBER_ERROR) do
        client = client_from_name(client_name.to_sym)
        no_two_factor = client.org_members(org, filter: '2fa_disabled')
                              .map { |member| member[:login] }.to_set
        client.org_members(org).map do |member|
          name = member[:login]
          [name, Collaborator.new(name, !no_two_factor.include?(name))]
        end.to_h
      end
    end

    def write_perms?(collab)
      collab[:permissions][:admin] || collab[:permissions][:push]
    end

    def collaborators(repo, client_name: '')
      wrap_with_github_error_handler(template: COLLABORATOR_ERROR, repo: repo) do
        client = client_from_name(client_name.to_sym)
        begin
          client.collabs(repo).select { |c| write_perms?(c) }.map do |collab|
            [collab[:login], Collaborator.new(collab[:login], false)]
          end.to_h
        rescue Octokit::Forbidden
          []
        end
      end
    end

    def branches(repo, sha, client_name: '')
      wrap_with_github_error_handler(template: BRANCH_ERROR, repo: repo, sha: sha) do
        client = client_from_name(client_name.to_sym)
        client.commit_branches(repo, sha, accept: PREVIEW_HEADER)
              .map { |b| { name: b.name, protection: b.protected } }
      end
    end

    def commit(repo, sha, client_name: '')
      wrap_with_github_error_handler(template: COMMIT_ERROR, repo: repo, sha: sha) do
        return Commit.new(sha, Time.now) if sha.eql? NIL_SHA

        client = client_from_name(client_name.to_sym)
        data = client.commit(repo, sha)
        branch_data = branches(repo, sha, client_name: client_name)
        Commit.new(sha, data.commit.committer.date, branch_data)
      end
    end

    def review_comments(repo, sha, since: nil, client_name: '')
      wrap_with_github_error_handler(template: COMMENT_ERROR, repo: repo, sha: sha) do
        client = client_from_name(client_name.to_sym)
        pulls = client.commit_pulls(repo, sha, accept: PREVIEW_HEADER)
        # TODO: this call does not abide by auto-pagination for some reason...
        # TODO: will this fail if since is nil?
        return [] if pulls&.empty?

        options = since ? { since: since } : {}
        comments = client.get(pulls.first.rels[:comments].href, options)
        # PR comments are issue comments. Issue comments only sort ascending...
        comments.select { |c| c.updated_at == c.created_at }.map do |comment|
          Comment.new(comment.user.login, comment.body, comment.created_at)
        end
      end
    end

    private

    def client_from_name(client_name)
      @alt_clients[client_name.to_sym] || @client
    end

    def error_for_github_error(github_error)
      MIRROR_ERROR_MAP.fetch(github_error, ClientGenericError)
    end

    def wrap_with_github_error_handler(template:, repo: '', sha: '')
      yield
    rescue *MIRROR_ERROR_MAP.keys => e
      raise error_for_github_error(e.class), format(
        template, repo: repo, sha: sha, msg: e.to_s
      )
    end
  end
end
