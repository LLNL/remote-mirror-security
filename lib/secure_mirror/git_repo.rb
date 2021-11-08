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

module SecureMirror
  # Inspects a git repo on disk and gathers info about it
  class GitRepo
    attr_reader :git_config

    def initialize(git_config_file)
      @repo_name = ''
      @git_config = nil
      @git_config_file = git_config_file.strip
      # `pwd` for the hook will be the git directory itself
      @git_config = IniFile.load(@git_config_file)
      return unless @git_config

      @remote_cfg = @git_config.select do |k, v|
        k.include?('remote') && v.include?('url')
      end
    end

    def new_repo?
      @git_config.nil?
    end

    def remote?
      !@remote_cfg.empty?
    end

    def misconfigured?
      @remote_cfg.size > 1
    end

    def remote_name
      return '' unless remote?

      @remote_cfg[0][0]
    end

    def url
      return '' if remote_name.empty?

      @git_config[remote_name]['url']
    end

    def name
      return '' if remote_name.empty?

      url = @git_config[remote_name]['url']
      # can't use ruby's URI, it *won't* parse git ssh urls
      # case examples:
      #   git@github.com:LLNL/SSHSpawner.git
      #   https://github.com/tgmachina/test-mirror.git
      @name ||= url.split(':')[-1]
                   .gsub('.git', '')
                   .split('/')[-2..-1]
                   .join('/')
    end

    def hashed?
      @git_config_file.split('/').include? '@hashed'
    end

    def wiki?
      @git_config_file.split('/')[-2].include? '.wiki.'
    end
  end
end
