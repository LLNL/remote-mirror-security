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

require 'spec_helper'

# serializable mock object
class MockObject
  def as_json(*)
    { klass: self.class.name, test: 'foo', bar: [{ name: 'baz' }] }
  end

  def to_json(*options)
    as_json(*options).to_json(*options)
  end

  def self.from_json(json_obj)
    new(json_obj[:test])
  end

  def initialize(*); end
end

RSpec.describe SecureMirror::CachingMirrorClient, '#unit' do
  let(:client) { double }
  let(:cache_dir) { '/tmp/test' }
  let(:mirror_client) do
    SecureMirror::CachingMirrorClient.new(
      client,
      cache_dir: cache_dir
    )
  end

  before(:each) do
    allow(client).to receive(:config)
    FileUtils.rm_rf cache_dir if File.exist? cache_dir
  end

  context 'methods to support caching' do
    it 'produces a unique key for the cache' do
      # TODO: edges
      method_name = 'foo'
      args = [1, 2, { bar: 3 }]
      args_different = [1, 2]
      first_key = mirror_client.cache_key(method_name, args)
      expect(first_key.length).not_to be 0
      second_key = mirror_client.cache_key(method_name, args_different)
      expect(second_key).not_to eq first_key
    end
  end

  context 'accepts an "expires" keyword argument but does not pass it on' do
    let(:expires) { mirror_client.strip_expires(args) }

    context 'when the args list contains an expires keyword arg' do
      let(:args) { [1, 2, { bar: 3, expires: 300 }] }

      it 'is stripped and returned' do
        expect(expires).to be_a Time
      end
    end

    context 'when the args list does not contain an expires keyword' do
      let(:args) { [1, 2, { bar: 3 }] }

      it 'uses a default expiration' do
        expect(expires).to be_a Time
        expect(expires >= Time.now).to be true
      end
    end
  end

  context 'serialization' do
    it 'can restore a hash of objects from json' do
      data = JSON.parse(
        JSON.dump((1..1000).map { |i| [i, MockObject.new] }.to_h),
        symbolize_names: true
      )
      restored = mirror_client.restore_objects(data)
      expect(restored.values.first.is_a?(MockObject)).to be true
    end

    it 'can restore a single object from json' do
      data = JSON.parse(
        JSON.dump(MockObject.new),
        symbolize_names: true
      )
      restored = mirror_client.restore_objects(data)
      expect(restored.is_a?(MockObject)).to be true
    end

    it 'can restore an array of objects from json' do
      data = JSON.parse(
        JSON.dump((1..1000).map { MockObject.new }),
        symbolize_names: true
      )
      restored = mirror_client.restore_objects(data)
      expect(restored.first.is_a?(MockObject)).to be true
    end

    it 'can restore an empty hash from json' do
      data = {}
      restored = mirror_client.restore_objects(data)
      expect(restored.empty?).to be true
    end

    it 'can restore an empty array from json' do
      data = []
      restored = mirror_client.restore_objects(data)
      expect(restored.empty?).to be true
    end
  end

  context 'builds a cache of objects' do
    let(:key) { 'foo' }
    let(:expiry_time) { Time.now + 300 }
    let(:data) { { bar: 'baz', expires: expiry_time } }

    before do
      mirror_client.write_cache(key, data)
    end

    it 'stores it in memory' do
      expect(mirror_client.cache[key]).to be data
    end

    it 'writes data to a file' do
      expect(File.exist?(mirror_client.cache_file(key))).to be true
    end

    context 'when data is stored in memory' do
      it 'returns data stored in memory' do
        cached = mirror_client.read_cache(key)
        expect(cached).to be data
      end
    end

    context 'when data is stored in a cache file' do
      it 'returns data stored in the cache file' do
        mirror_client.cache = {}
        cached = mirror_client.read_cache(key)

        expect(cached[:bar]).to eq 'baz'
        expect(cached[:expires].to_i).to be_within(1).of expiry_time.to_i
      end
    end
  end

  context 'cached call' do
    before do
      allow(client).to receive(:test) { [] }
    end

    it 'caches a call' do
      mirror_client.test('foo', 'bar')
      mirror_client.test('foo', 'bar')

      expect(client).to have_received(:test).once

      mirror_client.cache = {}
      mirror_client.test('foo', 'bar')
      # should not receive it again fulfilled from file
      expect(client).to have_received(:test).once
    end

    it 'repeats the call if the cache has expired' do
      mirror_client.test('foo', 'bar', expires: 0)
      expect(client).to have_received(:test).once
      mirror_client.test('foo', 'bar', expires: 0)
      expect(client).to have_received(:test).twice
    end
  end
end
