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

require 'yaml'
require 'json'
require 'fileutils'
require 'helpers'
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
                             alt_tokens: access_tokens[:external],
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
      else
        raise(StandardError, 'Unable to find client using git config')
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

    def initialize(config, repo, logger)
      @config = config
      @repo = repo
      @logger = logger
    end
  end

  def self.gitlab_shell_path
    omnibus_path = '/opt/gitlab/embedded/service/gitlab-shell'
    source_path = '/home/git/gitlab-shell'
    return omnibus_path if File.exist?(omnibus_path)

    source_path
  end

  def self.gitlab_shell_config
    YAML.load_file(File.join(gitlab_shell_path, 'config.yml'))
  end

  def self.gitlab_api_url
    base = gitlab_shell_config['gitlab_url'] || 'http://localhost'
    "#{base}/api/v4"
  end

  def self.mirrored_in_gitlab?(token)
    gl_repository = ENV['GL_REPOSITORY']
    raise(StandardError, 'GL_REPOSITORY undefined') unless gl_repository

    project = gl_repository.tr('project-', '')
    url = "#{gitlab_api_url}/projects/#{project}"
    headers = { 'PRIVATE-TOKEN': token }
    resp = SecureMirror.http_get(url, headers: headers)

    raise(StandardError, 'mirror info unavailable') unless resp.code == '200'

    JSON.parse(resp.body)['mirror']
  end

  def self.mirrored_status_file
    '.mirrored'
  end

  def self.cache_mirrored_status(mirrored)
    FileUtils.touch(mirrored_status_file) if mirrored
    mirrored
  end

  def self.mirrored?
    File.file?(mirrored_status_file)
  end

  def self.remove_mirrored_status
    mirrored = mirrored?
    File.delete(mirrored_status_file) if mirrored
    mirrored
  end

  def self.cache_for_platform(platform, token)
    case platform
    when 'gitlab' then cache_mirrored_status(mirrored_in_gitlab?(token))
    else raise(StandardError, 'Unable to determine if repo is a mirror')
    end
  end

  def self.evaluate?(phase, platform, token)
    case phase
    when 'pre-receive' then cache_for_platform(platform, token)
    when 'update' then mirrored?
    when 'post-receive' then remove_mirrored_status
    end
  end

  def self.evaluate_changes(phase, platform,
                            config_file: 'config.json',
                            git_config_file: Dir.pwd + '/config',
                            token: nil)
    config = JSON.parse(File.read(config_file), symbolize_names: true)
    logger = SecureMirror.init_logger(config)
    return SecureMirror::Codes::OK unless evaluate?(phase, platform, token)

    repo = GitRepo.new(git_config_file)
    setup = Setup.new(config, repo, logger)
    setup.policy_class.new(config, phase, setup.client, repo, logger).evaluate
  rescue StandardError => e
    # if anything goes wrong, cancel the changes
    logger.error("#{e}:\n#{e.backtrace.join("\n")}")
    SecureMirror::Codes::GENERAL_ERROR
  end
end
