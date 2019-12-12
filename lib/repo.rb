require 'set'
require 'time'
require 'uri'
require 'inifile'
require 'logger'

require 'mirror_security'
require 'collaborator'
require 'commit'
require 'comment'

# defines a git repo
class Repo
  include MirrorSecurity

  @signoff_body = 'lgtm'
  @client = nil
  @name = ''
  @logger = nil
  # TODO: replace with enum
  @hook_type = 'update'
  @hook_args = {}
  @org_members = {}
  @collaborators = {}
  @commits = {}
  @comments = []

  attr_reader :collaborators
  attr_reader :commits
  attr_reader :comments
  attr_reader :org_members

  attr_accessor :logger

  def init_logger
    @logger = Logger.new(STDERR)
    @logger = Logger.new(STDOUT)
    @logger.level = ENV['SM_LOG_LEVEL'] || Logger::INFO
  end

  def branch_name_from_ref
    @hook_args[:ref_name].split('/')[-1]
  end

  def protected_branch?
    branch_name = branch_name_from_ref
    false
  end

  def commit_info(sha)
    # stub. dates will usually come back from an api as a string
    { date: Time.now }
  end

  def init_trusted_org_members
    {}
  end

  def init_collaborators
    {}
  end

  def init_comments
    []
  end

  def init_commits
    # TODO: the "hook_args" that get supplied change based on hook_type
    new_hash = {}
    [@hook_args[:current_sha], @hook_args[:future_sha]].each do |sha|
      info = commit_info(sha)
      @logger.debug{ 'Commit %s was created %s' % [sha, info[:date]] }
      new_hash[sha] = Commit.new(sha, info[:date])
    end
    new_hash
  end

  def init_remote_info
    # initialize all the info needed from a remote to satisfy the
    # MirrorSecurity module
    @org_members = init_trusted_org_members
    @collaborators = init_collaborators
    @commits = init_commits
    @comments = init_comments
  end

  def initialize(hook_args, clients: {}, trusted_org: '', signoff_body: 'lgtm')
    init_logger
    @logger.debug('Starting repo initialization')
    @hook_args = hook_args
    @name = @hook_args[:repo_name]
    @client = clients[:main]
    @external_client = clients[:external] || clients[:main]
    @trusted_org = trusted_org
    @signoff_body = signoff_body
    init_remote_info
    @logger.debug('Finished initializing repo')
  end
end
