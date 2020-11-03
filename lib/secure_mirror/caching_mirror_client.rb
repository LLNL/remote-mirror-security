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
  class CachingMirrorClient
    attr_accessor :cache, :client, :config, :default_expiration

    def initialize(client, cache_dir: '.sm', default_expiration: 30)
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

    def restorable_array_data?(data)
      !data.empty? && data[0][:klass]
    end

    def restorable_hash_data?(data)
      data[:klass] || !data.values.empty? && data.values.first[:klass]
    end

    def restore_objects(data)
      case data
      when Array
        return data unless restorable_array_data?(data)

        restore_array(data)
      when Hash
        return data unless restorable_hash_data?(data)

        restore_hash(data)
      end
    end

    def read_from_memory(key)
      @cache[key]
    end

    def read_from_file(key)
      return unless File.exist?(cache_file(key))

      cached = JSON.parse(File.read(cache_file(key)), symbolize_names: true)
      cached[:data] = restore_objects(cached[:data])
      cached[:expires] = Time.parse(cached[:expires])
      @cache[key] = cached
      cached
    end

    def read_cache(key)
      read_from_memory(key) || read_from_file(key)
    end

    def write_cache(key, obj)
      File.write(cache_file(key), JSON.dump(obj))
      @cache[key] = obj
    end

    def cache_call(method, *args)
      expires = strip_expires(args)
      key = cache_key(method, args.to_s)
      cached = read_cache(key)

      return cached[:data] if cached && cached[:expires] > Time.now

      write_cache(key,
                  expires: expires,
                  data: @client.public_send(method, *args))[:data]
    end

    private

    def respond_to_missing?(method, *)
      @client.respond_to? method
    end

    def method_missing(method, *args, &_block)
      return super unless respond_to_missing? method

      cache_call(method, *args)
    end
  end
end