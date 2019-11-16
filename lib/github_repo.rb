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
    # stub. dates will usually come back from an api as a string
    commit = client.commit(@name, sha)
    { date: commit.commit.author.date }
  end

  def init_collaborators
    no_two_factor = Set.new
    org = @name.split('/')[0]
    @client.organization_members(org, filter: '2fa_disabled').each do |member|
      no_two_factor.add(member['login'])
    end

    @client.collabs(repo_name).to_h do |collab|
      username = collab['login']
      trusted = @client.organization_member?(org, username) &&
                !no_two_factor.include?(username)
      [username, Collaborator.new(username, trusted)]
    end
  end

  def init_comments
    @client.auto_paginate = true
    pulls = @client.commit_pulls(
      @name,
      @change_args[:future_sha],
      accept: Octokit::Preview::PREVIEW_TYPES[:commit_pulls]
    )
    comments = pulls.first.rels[:comments].get.data
    comments.reverse.collect do |comment|
      Comment.new(comment.user.login, comment.body, comment.updated_at)
    end
  end
end
