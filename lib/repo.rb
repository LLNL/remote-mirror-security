require 'set'
require 'date'
require 'uri'
require 'inifile'

require 'mirror_security'
require 'collaborator'
require 'commit'
require 'comment'

# defines a git repo
class Repo
  include MirrorSecurity

  @signoff_body = 'lgtm'
  @git_config = nil
  @trusted_orgs = Set.new
  @client = nil
  @name = ''
  @url = ''
  @mirror = false
  # TODO: replace with enum
  @hook_type = 'update'
  @change_args = {}
  @collaborators = {}
  @commits = {}
  @comments = []

  attr_reader :mirror
  attr_reader :collaborators
  attr_reader :commits
  attr_reader :comments

  def in_org?
    @trusted_orgs.include?(@name)
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
    { name: mirror_name, is_mirror: !mirror_cfg.empty? }
  end

  def protected_branch?(branch_name)
    false
  end

  def commit_info(sha)
    # stub. dates will usually come back from an api as a string
    { date: Date.today.to_s }
  end

  def parse_repo_name(url)
    URI.parse(url.slice('.git')).path
  end

  def init_collaborators(repo_name)
    {}
  end

  def init_commits(change_args)
    # TODO: the "change_args" that get supplied change based on hook_type
    new_hash = {}
    branch_name = change_args[:ref_name].split('/')[-1]
    protected_branch = protected_branch?(branch_name)
    [change_args[:current_sha], change_args[:future_sha]].each do |sha|
      new_hash[sha] = Commit.new(sha, branch_name,
                                 commit_info(sha)[:date], protected_branch)
    end
    new_hash
  end

  def init_comments(change_args)
    []
  end

  def initialize(change_args, git_config, client = nil, trusted_orgs = Set.new)
    @git_config = git_config
    info = mirror_info(@git_config)
    @url = git_config[info[:name]]['url']
    @name = parse_repo_name(@url)
    @mirror = info[:is_mirror]
    @change_args = change_args
    @client = client
    @collaborators = init_collaborators(@name)
    @commits = init_commits(change_args)
    @comments = init_comments(change_args)
    @trusted_orgs = trusted_orgs
  end
end
