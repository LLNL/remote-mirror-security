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

require 'logger'
require 'ostruct'
require 'secure_mirror'
require 'default_policy'

RSpec.describe SecureMirror, '#unit' do
  before(:each) do
  end

  after(:each) do
    f = SecureMirror.mirrored_status_file
    File.unlink f if File.exist? f
  end

  context 'helpers' do
    it 'caches mirroring status to a known file' do
      expect(SecureMirror.cache_mirrored_status(true)).to be true
      expect(File.file?(SecureMirror.mirrored_status_file)).to be true
    end

    it 'does not create a file if the mirror status is false' do
      expect(SecureMirror.cache_mirrored_status(false)).to be false
      expect(File.file?(SecureMirror.mirrored_status_file)).to be false
    end

    it 'can remove cached mirror status' do
      SecureMirror.cache_mirrored_status(true)
      expect(SecureMirror.remove_mirrored_status).to be true
      expect(File.file?(SecureMirror.mirrored_status_file)).to be false
    end
  end
end

RSpec.describe SecureMirror::Setup, '#unit' do
  before(:each) do
    @config = JSON.parse(File.read(__dir__ + '/fixtures/config.json'),
                         symbolize_names: true)
    @repo = SecureMirror::GitRepo.new(__dir__ + '/fixtures/config')
    @logger = Logger.new(STDOUT)
    @setup = SecureMirror::Setup.new(@config, @repo, @logger)
  end

  after(:each) do
  end

  context 'policy setup' do
    it 'gets a default policy class when none is defined in config' do
      @config[:policy_definition] = nil
      @config[:policy_class] = nil
      @setup = SecureMirror::Setup.new(@config, @repo, @logger)
      expect(@setup.policy_class).to be SecureMirror::DefaultPolicy
    end
  end

  context 'client setup' do
    it 'sets up and returns a client based on config (github)' do
      expect(@setup.client).not_to be nil
    end
  end
end
