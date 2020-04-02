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
require 'fileutils'
require 'git_repo'
require 'mirror_client'
require 'default_policy'

# secure mirror
module SecureMirror
  # client and policy setup
  class Setup
    def github_client
      require 'github_mirror_client'
      access_tokens = @config[:repo_types][:github][:access_tokens]
      GitHubMirrorClient.new(access_tokens[:main],
                             alt_clients: access_tokens[:external],
                             config: @config[:repo_types][:github])
    end

    def caching_client(client)
      conf = @config[:cache]
      CachingMirrorClient.new(client,
                              cache_dir: conf[:dir],
                              default_expiration: conf[:default_expiration])
    end

    def client
      case @repo.url.downcase
      when /github/
        client = github_client
      end
      return client unless @config[:cache][:enable]

      caching_client(client)
    rescue LoadError => e
      @logger.error('Unable to load client: ' + e.to_s)
    end

    def policy_class
      definition = @config[:policy_definition]
      klass = @config[:policy_class]
      return DefaultPolicy unless definition && klass

      require definition
      SecureMirror.class_from_string(klass)
    end

    def initialize(config, phase, repo, logger)
      @config = config
      @phase = phase
      @repo = repo
      @logger = logger
    end
  end

  def mirrored_in_gitlab?
    gl_repository = ENV['GL_REPOSITORY']
    raise(StandardError, 'GL_REPOSITORY undefined') unless gl_repository

    gitlab_project_id = gl_repository.tr('project-', '')
    query = "SELECT mirror FROM projects WHERE id=#{gitlab_project_id};"
    `gitlab-psql -d gitlabhq_production -t -c '#{query}'`.strip == 't'
  end

  def mirrored_status_file
    '.mirrored'
  end

  def cache_mirrored_status(mirrored)
    FileUtils.touch(mirrored_status_file) if mirrored
    mirrored
  end

  def mirrored?
    File.file?(mirrored_status_file)
  end

  def remove_mirrored_status
    mirrored = mirrored?
    File.delete(mirrored_status_file) if mirrored
    mirrored
  end

  def cache_for_platform(platform)
    case platform
    when 'gitlab' then cache_mirrored_status(mirrored_in_gitlab?)
    else raise(StandardError, 'Unable to determine if repo is a mirror')
    end
  end

  def evaluate?(phase, platform)
    case phase
    when 'pre-receive' then cache_for_platform(platform)
    when 'update' then mirrored?
    when 'post-receive' then remove_mirrored_status
    end
  end

  def evaluate_changes(phase, platform, config_file: 'config',
                       git_config_file: Dir.pwd + '/config')
    return SecureMirror::Codes::OK unless evaluate?(phase, platform)

    config = JSON.parse(File.read(config_file), symbolize_names: true)
    repo = GitRepo.new(git_config_file)
    logger = SecureMirror.init_logger(config)
    setup = Setup.new(config, phase, repo, logger)
    setup.policy_class.new(config, phase, setup.client, repo, logger).evaluate
  rescue StandardError => e
    # if anything goes wrong, cancel the changes
    logger.error(e)
    SecureMirror::Codes::GENERAL_ERROR
  end
end
