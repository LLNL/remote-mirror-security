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

require 'inifile'
require 'yaml'
require 'date'
require 'time'
require 'json'
require 'fileutils'
require 'logger'
require 'net/http'
require 'digest/sha2'
require 'octokit'
require 'pathname'
require 'secure_mirror/policy'
require 'secure_mirror/mirror_client'

Dir[File.join(__dir__, 'secure_mirror', '*.rb')].sort
  .entries.reject{ |f|  f.end_with?('/secure_mirror/mirror_client.rb', '/secure_mirror/policy.rb') }
  .each { |f| require(f) }

# secure mirror
module SecureMirror
  NIL_SHA = '0000000000000000000000000000000000000000'
  CLIENT_ERRORS = [
    ClientUnauthorized,
    ClientForbidden,
    ClientServerError,
    ClientNotFound,
    ClientGenericError
  ].freeze

  def self.mirrored_in_gitlab?(gitlab_url, repo, token)
    gl_repository = ENV['GL_REPOSITORY']
    raise(StandardError, 'GL_REPOSITORY undefined') unless gl_repository

    project = gl_repository.sub('project-', '')
    url = "#{gitlab_url}/api/v4/projects/#{project}"
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

  def self.cache_for_platform(repo, platform, config)
    token = config[:mirror_check_token]
    remove_mirrored_status
    mirrored_status = mirrored_in_gitlab?(config[:gitlab_url], repo, token)
    return cache_mirrored_status(mirrored_status) if platform == 'gitlab'
    raise(StandardError, 'Unable to determine if repo is a mirror')
  end

  # Based upon the potential evaluate_prefixes_only configuration, identify if evaluate should be skipped.
  def self.skip_prefix?(prefixes)
    return false if prefixes.nil? || prefixes.dig(:project_paths).to_a.empty?
    gl_project_path = ENV['GL_PROJECT_PATH']
    raise(StandardError, 'GL_PROJECT_PATH undefined') unless gl_project_path
    return gl_project_path.start_with?(*prefixes.dig(:project_paths))
  end

  def self.evaluate?(repo, phase, platform, config)
    return false if skip_prefix?(config.dig(:evaluate_prefixes_only))

    case phase
    when 'pre-receive' then cache_for_platform(repo, platform, config)
    when 'update' then mirrored?
    when 'post-receive' then remove_mirrored_status
    end
  end

  def self.evaluate_changes(phase,
                            platform,
                            config_file: 'config.json',
                            git_config_file: Dir.pwd + '/config')
    config = JSON.parse(File.read(config_file), symbolize_names: true)
    logger = SecureMirror.init_logger(config)
    repo = GitRepo.new(git_config_file)
    return SecureMirror::Codes::OK if repo.hashed? && repo.wiki?
    return SecureMirror::Codes::OK unless evaluate?(repo, phase, platform, config)

    setup = Setup.new(config, repo, logger)
    setup.policy_class.new(config, phase, setup.client, repo, logger).evaluate
  rescue StandardError => e
    # if anything goes wrong, cancel the changes
    logger.error(e)
    logger.debug(e.backtrace.join("\n"))
    SecureMirror::Codes::GENERAL_ERROR
  end
end
