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

require 'helpers'
require 'mirror_client'

module SecureMirror
  # defines a policy for mirror security to enforce
  class Policy
    def pre_receive
      Codes::OK
    end

    def post_receive
      Codes::OK
    end

    def update
      Codes::OK
    end

    def hook_args
      # variables provided by the git hook depend on stage
      return @args if @args

      case @phase
      when 'pre-receive', 'post-receive'
        @args = ARGV.each_slice(3).map do |current_sha, future_sha, ref_name|
          {
            current_sha: current_sha,
            future_sha: future_sha,
            ref_name: ref_name
          }
        end
      when 'update'
        @args = { ref_name: ARGV[0], current_sha: ARGV[1], future_sha: ARGV[2] }
      end
    end

    def evaluate
      @logger.debug(format('In phase %<phase>s', phase: @phase))
      case @phase
      when 'pre-receive' then pre_receive
      when 'update' then update
      when 'post-receive' then post_receive
      end
    rescue *SecureMirror::CLIENT_ERRORS => e
      @logger.error('Uncaught client error: ' + e.to_s)
      Codes::CLIENT_ERROR
    rescue StandardError => e
      @logger.error('Uncaught error: ' + e.to_s)
      Codes::GENERAL_ERROR
    end

    def initialize(config, phase, client, repo, logger)
      @config = config
      @phase = phase
      @client = client
      @repo = repo
      @logger = logger
      @args = nil
    end
  end
end
