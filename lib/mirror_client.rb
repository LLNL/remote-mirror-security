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
require 'digest/sha2'

class MirrorClientUnauthorized < StandardError; end
class MirrorClientForbidden < StandardError; end
class MirrorClientServerError < StandardError; end
class MirrorClientNotFound < StandardError; end
class MirrorClientGenericError < StandardError; end

# wraps MirrorClient and caches results in memory or to a file
class CachingMirrorClient < SimpleDelegator
  @cache = {}
  @cache_dir = ''
  @default_expiration = Time.now + 5 * 60

  attr_accessor :default_expiration

  def initialize(*args, cache_dir: '')
    @cache_dir = cache_dir
    super(*args)
  end

  def in_memory?
    @cache_dir.empty?
  end

  def cache_key(method_name, arg_string)
    Digest::SHA2.hexdigest "#{method_name}-#{arg_string}"
  end

  def read_cache(key)
    return @cache[key] if in_memory?

    filename = @cache_dir + "/#{key}"
    return unless File.exist? filename

    JSON.parse(File.read(filename), symbolize_names: true)
  end

  def write_cache(key, obj)
    if in_memory?
      @cache[key] = obj
    else
      File.write(@cache_dir + "/#{key}", JSON.dump(obj))
    end
    obj
  end

  def cached_call(for_method, *args)
    key = cache_key(for_method, args.to_s)
    cached = read_cache(key)
    return cached[:data] if cached && cached[:expires] >= Time.now
  end

  def org_members(*args)
    key = cache_key(__method__, args.to_s)
    cached_call(__method__, *args)
    kwargs = args[-1].is_a?(Hash) ? args[-1] : {}
    expires = kwargs[:expires] || @default_expiration
    write_cache(key, expires: expires, data: super(*args))[:data]
  end

  def collaborators(*args)
    cached_call(__method__, *args)
  end

  def commit(*args)
    cached_call(__method__, *args)
  end

  def review_comments(*args)
    cached_call(__method__, *args)
  end
end

# provides a generic REST API client interface for querying remote mirror data
class MirrorClient
  @client = nil
  @alt_clients = nil

  attr_accessor :client
  attr_accessor :alt_clients

  def org_members(org, client_name: '', expires: nil)
    raise NotImplementedError
  end

  def collaborators(repo, client_name: '', expires: nil)
    raise NotImplementedError
  end

  def commit(repo, sha, client_name: '', expires: nil)
    raise NotImplementedError
  end

  def review_comments(repo, sha, client_name: '', expires: nil)
    raise NotImplementedError
  end
end
