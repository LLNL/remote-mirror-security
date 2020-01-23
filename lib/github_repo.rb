require 'repo'
require 'logger'
require 'collaborator'
require 'octokit'

# GitHub specific repo
class GitHubRepo < Repo
  def protected_branch?
    return false unless @hook_args[:future_sha]

    branch_name = branch_name_from_ref
    branches = @client.commit_branches(
      @name,
      @hook_args[:future_sha],
      accept: Octokit::Preview::PREVIEW_TYPES[:commit_branches]
    )
    branches.any? do |b|
      b.protected && b.name == branch_name
    end
  end

  def commit_info(sha)
    return if sha.eql? '0000000000000000000000000000000000000000'

    commit = @client.commit(@name, sha)
    { date: commit.commit.author.date }
  rescue Octokit::UnprocessableEntity
    @logger.warn('Unable to query commit for sha %s' % sha)
  end

  def init_trusted_org_members
    members = {}
    begin
      no_two_factor = @client.org_members(@trusted_org, filter: '2fa_disabled')
                             .map { |member| member[:login] }.to_set
      @client.org_members(@trusted_org).each do |member|
        username = member[:login]
        members[username] = Collaborator.new(
          username,
          !no_two_factor.include?(username)
        )
      end
    rescue Octokit::NotFound
      @logger.error('Unable to query group membership for org %s' % org)
    end
    members
  end

  def init_collaborators
    collabs = {}
    begin
      @external_client.collabs(@name).each do |collab|
        username = collab[:login]
        in_org = @org_members[username] ? true : false
        in_org || @logger.info('%s is not in %s!' % [username, @trusted_org])
        two_factor_enabled = in_org && @org_members[username].trusted
        two_factor_enabled || @logger.info('%s has 2FA disabled!' % username)
        trusted = in_org && two_factor_enabled
        collabs[username] = Collaborator.new(username, trusted)
      end
    rescue Octokit::Unauthorized
      @logger.info('Unable to query collaborators for %s' % @name)
    rescue Octokit::Forbidden
      @logger.info('Unable to query collaborators for %s' % @name)
    end
    collabs
  end

  def init_comments
    pulls = @client.commit_pulls(
      @name,
      @hook_args[:future_sha],
      accept: Octokit::Preview::PREVIEW_TYPES[:commit_pulls]
    )
    filtered_comments = []
    begin
      comments = pulls.first.rels[:comments].get.data
    rescue NoMethodError
      @logger.info('PR comments for %s not found' % @name)
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

  def initialize(hook_args, clients: {}, trusted_org: '', signoff_body: 'lgtm',
                 logger: Logger.new(STDOUT))
    begin
      super
    rescue Octokit::Unauthorized => err
      @logger.error('Request to GitHub unauthorized: ' + err.to_s)
    rescue Octokit::Forbidden => err
      @logger.error('Request to GitHub forbidden: ' + err.to_s)
    rescue Octokit::ServerError => err
      @logger.error('Request to GitHub failed: ' + err.to_s)
    end
  end
end
