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
  @git_config = nil
  @client = nil
  @name = ''
  @url = ''
  @mirror = false
  # TODO: replace with enum
  @hook_type = 'update'
  @org_members = {}
  @change_args = {}
  @collaborators = {}
  @commits = {}
  @comments = []
  @logger = nil

  attr_reader :mirror
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

  def mirror_info(git_config)
    # pull all the remotes out of the config except the one marked "upstream"
    mirror_cfg = git_config.select do |k, v|
      k.include?('remote') && !k.include?('upstream') && v.include?('mirror')
    end

    if mirror_cfg.size > 1
      raise ArgumentError, 'too many mirrors configured', caller
    end

    mirror_name = mirror_cfg[0][0]
    @logger.debug { 'Mirror name: ' + mirror_name }
    { name: mirror_name, is_mirror: !mirror_cfg.empty? }
  end

  def branch_name_from_ref
    @change_args[:ref_name].split('/')[-1]
  end

  def protected_branch?
    branch_name = branch_name_from_ref
    false
  end

  def commit_info(sha)
    # stub. dates will usually come back from an api as a string
    { date: Time.now, protection_enabled: true }
  end

  def parse_repo_name(url)
    # ugh, ruby's URI *won't* parse git ssh urls
    # case examples:
    #   git@github.com:LLNL/SSHSpawner.git
    #   https://github.com/tgmachina/test-mirror.git
    url.split(':')[-1]
       .gsub('.git', '')
       .split('/')[-2..-1]
       .join('/')
  end

  def init_trusted_org_members
    {}
  end

  def init_collaborators
    {}
  end

  def init_commits
    # TODO: the "change_args" that get supplied change based on hook_type
    new_hash = {}
    [@change_args[:current_sha], @change_args[:future_sha]].each do |sha|
      info = commit_info(sha)
      @logger.debug{ 'Commit %s was created %s' % [sha, info[:date]] }
      new_hash[sha] = Commit.new(sha, info[:date])
    end
    new_hash
  end

  def init_comments
    []
  end

  def initialize(change_args, git_config, client = nil, external_client = nil,
                 trusted_org = '', signoff_body = 'lgtm')
    init_logger
    @logger.debug('Starting repo initialization')
    @git_config = git_config
    info = mirror_info(@git_config)
    @url = git_config[info[:name]]['url']
    @name = parse_repo_name(@url)
    @mirror = info[:is_mirror]
    @change_args = change_args
    @client = client
    @external_client = external_client || client
    @trusted_org = trusted_org
    @signoff_body = signoff_body
    @org_members = init_trusted_org_members
    @collaborators = init_collaborators
    @commits = init_commits
    @comments = init_comments
    @logger.debug('Finished initializing repo')
  end
end
