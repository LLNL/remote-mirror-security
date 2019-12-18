require 'json'
require 'logger'
require 'inifile'
require 'octokit'

# interface and setup for the correct secure-mirror repo implementation
class SecureMirror
  @repo = nil
  @config = nil
  @git_config = nil
  @logger = nil

  attr_reader :repo
  attr_reader :logger

  def init_logger(log_file)
    @logger = Logger.new(log_file)
    @logger.level = ENV['SM_LOG_LEVEL'] || Logger::INFO
  end

  def new_repo?
    @git_config.nil?
  end

  def mirror?
    !@mirror_cfg.empty?
  end

  def misconfigured?
    @mirror_cfg.size > 1
  end

  def mirror_name
    return '' unless mirror?
    @mirror_cfg[0][0]
  end

  def url
    return '' unless mirror_name
    @git_config[mirror_name]['url']
  end

  def name
    return '' unless mirror_name
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
    clients = {}
    config[:access_tokens].each do |type, token|
      clients[type] = Octokit::Client.new(per_page: 1000, access_token: token)
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

  def initialize(hook_args, config_file, git_config_file, log_file)
    # `pwd` for the hook will be the git directory itself
    conf = File.open(config_file)
    @config = JSON.parse(conf.read, symbolize_names: true)
    @git_config = IniFile.load(git_config_file)
    return unless @git_config
    init_logger(log_file)
    init_mirror_info
    @hook_args = hook_args
    @hook_args[:repo_name] = name
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

  begin
    sm = SecureMirror.new(hook_args, config_file, git_config_file, log_file)

    # if this is a brand new repo, or not a mirror allow the import
    if sm.new_repo? || !sm.mirror?
      return 0
    end

    # fail on invalid git config
    return 1 if sm.misconfigured?

    # if repo initialization was successful and we trust the change, allow it
    return 0 if sm.repo && sm.repo.trusted_change?
  rescue StandardError => err
    # if anything goes wrong, cancel the changes
    sm.logger.error(err)
    return 1
  end

  1
end
