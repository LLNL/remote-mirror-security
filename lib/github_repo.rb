require 'repo'
require 'collaborator'
require 'octokit'

# GitHub specific repo
class GitHubRepo < Repo
  def protected_branch?(branch_name)
    repo = @client.repo(@name)
    branches = repo.rels[:branches].get.data
    branches.any? do |b|
      b.protected && b.name == branch_name
    end
  end

  def commit_info(sha)
    commit = @client.commit(@name, sha)
    { date: commit.commit.author.date }
  end

  def init_collaborators
    return {} unless trusted_org?
    org = @name.split('/')[0]
    begin
      no_two_factor = @client.org_members(org, filter: '2fa_disabled')
                             .map { |member| member[:login] }
    rescue Octokit::NotFound
      @logger.error('Unable to query group membership for org %s' % org)
      return {}
    end

    collabs = {}
    @client.collabs(@name).each do |collab|
      username = collab[:login]
      in_org = @client.org_member?(org, username)
      two_factor_enabled = !no_two_factor.include?(username)
      trusted = in_org &&
                two_factor_enabled
      @logger.warn('%s is not in %s!' % [username, org]) unless in_org
      @logger.warn('%s has 2FA disabled!' % username) unless two_factor_enabled
      collabs[username] = Collaborator.new(username, trusted)
    end
    collabs
  end

  def init_comments
    @client.auto_paginate = true
    pulls = @client.commit_pulls(
      @name,
      @change_args[:future_sha],
      accept: Octokit::Preview::PREVIEW_TYPES[:commit_pulls]
    )
    filtered_comments = []
    begin
      comments = pulls.first.rels[:comments].get.data
    rescue NoMethodError
      @logger.error('Unable to retrieve associated PR comments for %s' % @name)
      return filtered_comments
    end
    # PR comments are done as issue comments. Issue comments only sort
    # ascending...
    comments.reverse_each do |comment|
      # comments can be edited: use un-edited comments only
      next unless comment.updated_at == comment.created_at
      filtered_comments << Comment.new(
        comment.user.login,
        comment.body,
        comment.created_at
      )
    end
    filtered_comments
  end

  def initialize(change_args, git_config, client = nil, trusted_orgs = Set.new,
                 signoff_body = 'lgtm')
    begin
      super
    rescue Octokit::Unauthorized => err
      @logger.error('Request to GitHub unauthorized: ' + err)
    rescue Octokit::Forbidden => err
      @logger.error('Request to GitHub forbidden: ' + err)
    rescue Octokit::ServerError => err
      @logger.error('Request to GitHub failed: ' + err)
    end
  end
end
