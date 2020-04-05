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

require 'helpers'
require 'collaborator'

module SecureMirror
  class ClientGenericError < StandardError; end
  class ClientUnauthorized < ClientGenericError; end
  class ClientForbidden < ClientGenericError; end
  class ClientServerError < ClientGenericError; end
  class ClientNotFound < ClientGenericError; end

  CLIENT_ERRORS = [
    ClientUnauthorized,
    ClientForbidden,
    ClientServerError,
    ClientNotFound,
    ClientGenericError
  ].freeze

  # wraps MirrorClient and caches results in memory or to a file
  class CachingMirrorClient
    attr_accessor :cache
    attr_accessor :client
    attr_accessor :config
    attr_accessor :default_expiration

    def initialize(client, cache_dir: '.sm', default_expiration: 5 * 60)
      @cache = {}
      @client = client
      @config = client.config
      @cache_dir = cache_dir
      @default_expiration = default_expiration
      FileUtils.mkdir_p @cache_dir
    end

    def cache_key(method_name, arg_string)
      Digest::SHA2.hexdigest "#{method_name}-#{arg_string}"
    end

    def cache_file(key)
      @cache_dir + "/#{key}"
    end

    def keyword_arguments(args)
      args[-1].is_a?(Hash) ? args[-1] : nil
    end

    def strip_expires(args)
      kwargs = keyword_arguments(args)
      provided_expires = kwargs && kwargs[:expires]
      args.pop if provided_expires && kwargs.size == 1
      lifetime = kwargs.delete(:expires) if provided_expires
      lifetime ||= @default_expiration
      Time.now + lifetime
    end

    def restore_hash(data)
      klass = SecureMirror.class_from_string(
        data[:klass] || data.values.first[:klass]
      )
      return klass.from_json(data) if data[:klass]

      data.map do |key, item|
        [key.to_s, klass.from_json(item)]
      end.to_h
    end

    def restore_array(data)
      klass = SecureMirror.class_from_string(data[0][:klass])
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
      cached = @cache[key]
      return cached if cached && cached[:expires] >= Time.now

      return unless File.exist?(cache_file(key))

      cached = JSON.parse(File.read(cache_file(key)), symbolize_names: true)
      cached[:data] = restore_objects(cached[:data])
      cached[:expires] = Time.parse(cached[:expires])
      @cache[key] = cached
    end

    def write_cache(key, obj)
      File.write(cache_file(key), JSON.dump(obj))
      @cache[key] = obj
    end

    def respond_to_missing?(method, *)
      @client.respond_to? method
    end

    def cache_call(method, *args)
      expires = strip_expires(args)
      key = cache_key(method, args.to_s)
      cached = read_cache(key)
      return cached[:data] if cached

      write_cache(key,
                  expires: expires,
                  data: @client.public_send(method, *args))[:data]
    end

    def method_missing(method, *args, &_block)
      return super unless respond_to_missing? method

      cache_call(method, *args)
    end
  end

  # provides a generic REST API client interface for querying remote mirror data
  class MirrorClient
    @client = nil
    @alt_clients = nil

    attr_accessor :client
    attr_accessor :alt_clients

    def org_members(org: '', client_name: '', expires: nil)
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
end
