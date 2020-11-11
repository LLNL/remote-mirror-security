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
  class Setup
    def initialize(config, repo, logger)
      @config = config
      @repo = repo
      @logger = logger
    end

    def github_client
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
        msg = "unsupported mirror type: #{@repo.url}"
        raise(StandardError, msg)
      end
      return client unless @config[:cache][:enable]

      caching_client(client)
    end

    def policy_class
      definition = @config[:policy_definition]
      klass = @config[:policy_class]
      return DefaultPolicy unless definition && klass

      require definition
      SecureMirror.class_from_string(klass)
    end
  end
end