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

require 'json'
require 'logger'
require 'fileutils'
require 'git_repo'
require 'mirror_client'

module SecureMirror
  def hook_args(phase)
    # variables provided by the git hook depend on stage
    case phase
    when 'pre-receive', 'post-receive'
      ARGV.each_slice(3).map do |old_sha, new_sha, ref_name|
        { old_sha: old_sha, new_sha: new_sha, ref_name: ref_name }
      end
    when 'update'
      { ref_name: ARGV[0], current_sha: ARGV[1], future_sha: ARGV[2] }
    end
  end

  def init_logger(log_file)
    log_dir = File.dirname(log_file)
    FileUtils.mkdir_p log_dir unless File.exist? log_dir
    level = ENV['SM_LOG_LEVEL'] || Logger::INFO
    Logger.new(log_file, level: level)
  end

  def github_client(access_tokens)
    require 'github_mirror_client'
    GitHubMirrorClient.new(access_tokens[:main],
                           alt_clients: access_tokens[:external])
  end

  def caching_client(client, config)
    CachingMirrorClient.new(client,
                            cache_dir: config[:dir],
                            default_expiration: config[:default_expiration])
  end

  def client_for_repo(repo, config)
    case repo.url.downcase
    when /github/
      client = github_client(config[:github][:access_tokens])
    end
    return client unless config[:cache][:enable]

    caching_client(client, config[:cache])
  end

  def policy_in_phase(policy, phase)
    case phase
    when 'pre-receive'
      policy.pre_receive
    when 'update'
      policy.update
    when 'post-receive'
      policy.post_receive
    end
  end

  def policy_from_config(config)
    return Policy unless config[:policy_definition]

    require config[:policy_definition]
    # TODO, instead of method, allow name to be defined in config
    load_policy_class
  rescue LoadError => e
    puts 'Error loading config: ' + e.to_s
  end

  def evaluate_changes(phase,
                       config_file: 'config',
                       git_config_file: Dir.pwd + '/config',
                       log_file: 'mirror.log')

    logger = init_logger(log_file)
    config = JSON.parse(File.read(config_file), symbolize_names: true)
    repo = GitRepo.new(git_config_file)
    client = client_for_repo(repo, config[:repo_types])
    policy_class = policy_from_config(config)
    return 1 unless policy_class

    policy = policy_class.new(
      config, client, repo, hook_args, logger
    )
    policy_in_phase(policy, phase)
  rescue StandardError => e
    # if anything goes wrong, cancel the changes
    logger.error(e)
    1
  end
end
