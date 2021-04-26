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
  # defines a policy for mirror security to enforce
  class Policy
    def initialize(config, phase, client, repo, logger)
      @config = config
      @phase = phase
      @client = client
      @repo = repo
      @logger = logger

      validate!
    end

    def validate!; end

    def pre_receive
      @logger.debug(format('evaluating %<phase>s', phase: @phase))
      Codes::OK
    end

    def post_receive
      @logger.debug(format('evaluating %<phase>s', phase: @phase))
      clear_cache
      Codes::OK
    end

    def update
      @logger.debug(format('evaluating %<phase>s', phase: @phase))
      Codes::OK
    end

    def clear_cache
      cache_dir = @config[:cache][:dir]
      FileUtils.rm_rf cache_dir if File.exist?(cache_dir)
    end

    def hook_args
      # variables provided by the git hook depend on stage
      @hook_args ||= case @phase
                     when 'pre-receive', 'post-receive'
                       ARGV.each_slice(3).map do |current_sha, future_sha, ref_name|
                         {
                           current_sha: current_sha,
                           future_sha: future_sha,
                           ref_name: ref_name
                         }
                       end
                     when 'update'
                       {
                         ref_name: ARGV[0], current_sha: ARGV[1], future_sha: ARGV[2]
                       }
                     end
    end

    def log_format_for_pre_receive
      original_formatter = Logger::Formatter.new
      @logger.formatter = proc { |severity, datetime, progname, msg|
        m = "#{@repo.name} : #{msg.dump}"
        original_formatter.call(severity, datetime, progname, m)
      }
    end

    def log_format_for_update
      original_formatter = Logger::Formatter.new
      ref = hook_args[:ref_name]
      short_sha = hook_args[:future_sha][0..6]
      @logger.formatter = proc { |severity, datetime, progname, msg|
        m = "#{@repo.name} : #{ref} : #{short_sha} : #{msg.dump}"
        original_formatter.call(severity, datetime, progname, m)
      }
    end

    def log_format_for_post_receive
      log_format_for_pre_receive
    end

    def evaluate
      @logger.debug(format('%<pclass>s : in phase %<phase>s',
                           pclass: self.class.name,
                           phase: @phase))
      case @phase
      when 'pre-receive'
        log_format_for_pre_receive
        pre_receive
      when 'update'
        log_format_for_update
        update
      when 'post-receive'
        log_format_for_post_receive
        post_receive
      end
    rescue *SecureMirror::CLIENT_ERRORS => e
      @logger.error("Uncaught client error: #{e}\n#{e.backtrace.join("\n")}")
      Codes::CLIENT_ERROR
    rescue StandardError => e
      @logger.error("Uncaught error: #{e}\n#{e.backtrace.join("\n")}")
      Codes::GENERAL_ERROR
    end
  end
end
