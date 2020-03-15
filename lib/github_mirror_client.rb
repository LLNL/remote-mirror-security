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

require 'octokit'
require 'mirror_client'
require 'comment'
require 'commit'
require 'collaborator'

NIL_SHA = '0000000000000000000000000000000000000000'

module SecureMirror
  # defines the GitHub mirror client
  class GitHubMirrorClient < MirrorClient
    @@mirror_error_map = {
      "Octokit::Unauthorized": ClientUnauthorized,
      "Octokit::Forbidden": ClientForbidden,
      "Octokit::NotFound": ClientNotFound,
      "Octokit::UnprocessableEntity": ClientGenericError,
      "Octokit::ServerError": ClientServerError
    }

    @@github_errors = [
      Octokit::Unauthorized,
      Octokit::Forbidden,
      Octokit::NotFound,
      Octokit::UnprocessableEntity,
      Octokit::ServerError
    ]

    attr_reader :github_errors

    def error_for_github_error(github_error)
      error_name = github_error.class.name.to_sym
      return ClientGenericError unless @@mirror_error_map[error_name]

      @@mirror_error_map[error_name]
    end

    def org_members(org, client_name: '')
      client = @alt_clients[client_name.to_sym] || @client
      no_two_factor = client.org_members(org, filter: '2fa_disabled')
                            .map { |member| member[:login] }.to_set
      client.org_members(org).map do |member|
        name = member[:login]
        [name, Collaborator.new(name, !no_two_factor.include?(name))]
      end.to_h
    rescue *@@github_errors => e
      raise error_for_github_error(e), format(
        'Could not query GitHub org members: %<msg>s', msg: e.to_s
      )
    end

    def collaborators(repo, client_name: '')
      client = @alt_clients[client_name.to_sym] || @client
      client.collabs(repo).map do |collab|
        [collab[:login], Collaborator.new(collab[:login], false)]
      end.to_h
    rescue *@@github_errors => e
      raise error_for_github_error(e), format(
        'Could not query GitHub collaborators for repo %<repo>s: %<msg>s',
        repo: repo, msg: e.to_s
      )
    end

    def branches(repo, sha, client_name: '')
      client = @alt_clients[client_name.to_sym] || @client
      preview_header = Octokit::Preview::PREVIEW_TYPES[:commit_branches]
      client.commit_branches(repo, sha, accept: preview_header)
            .map { |b| { name: b.name, protection: b.protected } }
    rescue *@@github_errors => e
      raise error_for_github_error(e), format(
        'Could not get branch info from GitHub %<repo>s and sha %<sha>s: %<msg>s',
        repo: repo, sha: sha, msg: e.to_s
      )
    end

    def commit(repo, sha, client_name: '')
      return Commit.new(sha, Time.now) if sha.eql? NIL_SHA

      client = @alt_clients[client_name.to_sym] || @client
      data = client.commit(repo, sha)
      branch_data = branches(repo, sha, client_name: client_name)
      Commit.new(sha, data.commit.author.date, branches: branch_data)
    rescue *@@github_errors => e
      raise error_for_github_error(e), format(
        'Could not get GitHub commit for repo %<repo>s and sha %<sha>s: %<msg>s',
        repo: repo, sha: sha, msg: e.to_s
      )
    end

    def review_comments(repo, sha, since: nil, client_name: '')
      client = @alt_clients[client_name.to_sym] || @client
      preview_header = Octokit::Preview::PREVIEW_TYPES[:commit_pulls]
      pulls = client.commit_pulls(repo, sha, accept: preview_header)
      # TODO: this call does not abide by auto-pagination for some reason...
      # TODO: will this fail if since is nil?
      comments = client.get(pulls.first.rels[:comments].href, since: since)
      # PR comments are issue comments. Issue comments only sort ascending...
      comments.select { |c| c.updated_at == c.created_at }.map do |comment|
        Comment.new(comment.user.login, comment.body, comment.created_at)
      end
    rescue *@@github_errors => e
      raise error_for_github_error(e), format(
        'Could not get GitHub issue comments for repo %<repo>s, %<sha>s: '\
        '%<msg>s',
        repo: repo, sha: sha, msg: e.to_s
      )
    end

    def initialize(token, alt_tokens: nil)
      @client = Octokit::Client.new(auto_paginate: true, access_token: token)
      return unless alt_tokens

      @alt_clients = {}
      alt_tokens.each do |name, alt_token|
        @alt_clients[name] = Octokit::Client.new(
          auto_paginate: true,
          access_token: alt_token
        )
      end
    end
  end
end
