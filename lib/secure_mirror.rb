# frozen_string_literal: true

require 'json'
require 'logger'
require 'fileutils'
require 'inifile'
require 'octokit'

# interface and setup for the correct secure-mirror repo implementation
class SecureMirror
  @repo = nil
  @config = nil
  @git_config = nil
  @logger = nil

  attr_reader :repo

  def new_repo?
    @git_config.nil?
  end

  def mirror?
    !@mirror_cfg.empty?
  end

  def deletion?
    @hook_args[:future_sha].eql?('0000000000000000000000000000000000000000')
  end

  def misconfigured?
    @mirror_cfg.size > 1
  end

  def mirror_name
    return '' unless mirror?

    @mirror_cfg[0][0]
  end

  def url
    return '' if mirror_name.empty?

    @git_config[mirror_name]['url']
  end

  def name
    return '' if mirror_name.empty?

    url = @git_config[mirror_name]['url']
    # can't use ruby's URI, it *won't* parse git ssh urls
    # case examples:
    #   git@github.com:LLNL/SSHSpawner.git
    #   https://github.com/tgmachina/test-mirror.git
    url.split(':')[-1]
       .gsub('.git', '')
       .split('/')[-2..-1]
       .join('/')
  end

  def init_mirror_info
    # pull all the remotes out of the config except the one marked "upstream"
    @mirror_cfg = @git_config.select do |k, v|
      k.include?('remote') && !k.include?('upstream') && v.include?('mirror')
    end
  end

  def init_github_repo
    require 'github_repo'
    config = @config[:repo_types][:github]
    return unless config

    tokens = config[:access_tokens]
    clients = {}
    clients[:main] = Octokit::Client.new(auto_paginate: true,
                                         access_token: tokens[:main])
    if tokens[:external] && tokens[:external][name]
      clients[:external] = Octokit::Client.new(
        auto_paginate: true,
        access_token: tokens[:external][name]
      )
    end
    GitHubRepo.new(@hook_args,
                   clients: clients,
                   trusted_org: config[:trusted_org],
                   signoff_body: config[:signoff_body],
                   logger: @logger)
  end

  def repo_from_config
    case url.downcase
    when /github/
      init_github_repo
    end
  end

  def initialize(hook_args, config_file, git_config_file, logger)
    # `pwd` for the hook will be the git directory itself
    @logger = logger
    @hook_args = hook_args
    return if deletion?

    conf = File.open(config_file)
    @config = JSON.parse(conf.read, symbolize_names: true)
    @git_config = IniFile.load(git_config_file)
    return unless @git_config

    init_mirror_info
    @hook_args[:repo_name] = name
    return if new_repo?

    @repo = repo_from_config
  end
end

def evaluate_changes(config_file: 'config.json',
                     git_config_file: Dir.pwd + '/config',
                     log_file: 'mirror.log')
  # the environment variables are provided by the git update hook
  hook_args = {
    ref_name: ARGV[0],
    current_sha: ARGV[1],
    future_sha: ARGV[2]
  }

  log_dir = File.dirname(log_file)
  FileUtils.mkdir_p log_dir unless File.exist? log_dir
  logger = Logger.new(log_file)
  logger.level = ENV['SM_LOG_LEVEL'] || Logger::INFO
  begin
    sm = SecureMirror.new(hook_args, config_file, git_config_file, logger)

    # if this is a brand new repo, or not a mirror allow the import
    if sm.new_repo?
      logger.info('Brand new repo, cannot read git config info')
      return 0
    elsif sm.deletion?
      logger.info('Allowing branch to be deleted')
      return 0
    elsif !sm.mirror?
      logger.info('Repo %s is not a mirror' % sm.name)
      return 0
    end

    # fail on invalid git config
    if sm.misconfigured?
      logger.error('Repo %s is misconfigured' % sm.name)
      return 1
    end

    # if repo initialization was successful and we trust the change, allow it
    if sm&.repo&.trusted_change?
      logger.info('Importing trusted changes from %s' % sm.name)
      return 0
    end
  rescue StandardError => e
    # if anything goes wrong, cancel the changes
    logger.error(e)
    return 1
  end

  1
end
