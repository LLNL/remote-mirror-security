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

module SecureMirror
  # Inspects a git repo on disk and gathers info about it
  class GitRepo
    @repo_name = ''
    @git_config = nil

    attr_reader :git_config

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
      return '' if mirror_name.empty?

      @git_config[mirror_name]['url']
    end

    def name
      return @repo_name if @repo_name

      return '' if mirror_name.empty?

      url = @git_config[mirror_name]['url']
      # can't use ruby's URI, it *won't* parse git ssh urls
      # case examples:
      #   git@github.com:LLNL/SSHSpawner.git
      #   https://github.com/tgmachina/test-mirror.git
      @repo_name = url.split(':')[-1]
                      .gsub('.git', '')
                      .split('/')[-2..-1]
                      .join('/')
    end

    def initialize(git_config_file)
      # `pwd` for the hook will be the git directory itself
      @git_config = IniFile.load(git_config_file)
      return unless @git_config

      @mirror_cfg = @git_config.select do |k, v|
        k.include?('remote') && !k.include?('upstream') && v.include?('mirror')
      end
    end
  end
end
