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

require 'collaborator'

class MirrorClientUnauthorized < StandardError; end
class MirrorClientForbidden < StandardError; end
class MirrorClientServerError < StandardError; end
class MirrorClientNotFound < StandardError; end
class MirrorClientGenericError < StandardError; end

# wraps MirrorClient and caches results in memory or to a file
class CachingMirrorClient
  attr_accessor :default_expiration

  def initialize(client, cache_dir: '', default_expiration: Time.now + 5 * 60)
    @cache = {}
    @client = SimpleDelegator.new(client)
    @cache_dir = cache_dir
    @default_expiration = default_expiration
  end

  def in_memory?
    @cache_dir.empty?
  end

  def cache_key(method_name, arg_string)
    Digest::SHA2.hexdigest "#{method_name}-#{arg_string}"
  end

  def cache_file(key)
    @cache_dir + "/#{key}"
  end

  def strip_expires(args)
    kwargs = args[-1].is_a?(Hash) ? args[-1] : nil
    return @default_expiration unless kwargs

    expires = kwargs.delete(:expires) || @default_expiration
    args.pop if kwargs.empty?
    expires
  end

  def class_from_string(klass)
    return Object.const_get(klass) unless klass.include?(':')

    klass.split('::').inject(Object) { |o, c| o.const_get c }
  end

  def restore_hash(data)
    klass = class_from_string(data[:klass] || data.values.first[:klass])
    return klass.from_json(data) if data[:klass]

    data.map do |key, item|
      [key.to_s, klass.from_json(item)]
    end.to_h
  end

  def restore_array(data)
    klass = class_from_string(data[0][:klass])
    data.map do |item|
      klass.from_json(item)
    end
  end

  def restore_objects(data)
    if data.is_a?(Array)
      return data unless data[0][:klass]

      restore_array(data)
    elsif data.is_a?(Hash)
      return data unless data[:klass] || data.values.first[:klass]

      restore_hash(data)
    end
  end

  def read_cache(key)
    return @cache[key] if in_memory?

    return unless File.exist?(cache_file(key))

    cached = JSON.parse(File.read(cache_file(key)), symbolize_names: true)
    cached[:data] = restore_objects(cached[:data])
    cached[:expires] = Time.parse(cached[:expires])
    cached
  end

  def write_cache(key, obj)
    if in_memory?
      @cache[key] = obj
    else
      File.write(cache_file(key), JSON.dump(obj))
    end
    obj
  end

  def respond_to_missing?
    @client.__getobj__.respond_to? method
  end

  def method_missing(method, *args, &_block)
    return super unless @client.__getobj__.respond_to? method

    expires = strip_expires(args)
    key = cache_key(method, args.to_s)
    cached = read_cache(key)
    return cached[:data] if cached && cached[:expires] >= Time.now

    write_cache(key,
                expires: expires,
                data: @client.__getobj__.public_send(method, *args))[:data]
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
