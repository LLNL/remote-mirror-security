require 'repo'
require 'collaborator'
require 'octokit'

# GitHub specific repo
class GitHubRepo < Repo
  @trusted_org = nil

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
    no_two_factor = @client.organization_members(org, filter: '2fa_disabled')
                           .map{ |member| member[:login] }
    collabs = {}
    @client.collabs(@name).each do |collab|
      username = collab[:login]
      trusted = @client.organization_member?(org, username) &&
                !no_two_factor.include?(username)
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
    comments = pulls.first.rels[:comments].get.data
    # comments can be edited by the PR opener and collabs: use original only
    comments.reverse_each do |comment|
      if comment.updated_at == comment.created_at
        filtered_comments << Comment.new(
                               comment.user.login,
                               comment.body,
                               comment.updated_at
                             )
      end
    end
    filtered_comments
  end
end
