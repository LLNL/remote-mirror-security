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

RSpec.describe SecureMirror::Setup, '#unit' do
  include FakeFS::SpecHelpers

  let(:config) do
    JSON.parse(File.read(config_filename), symbolize_names: true)
  end
  let(:config_filename) { __dir__ + '/fixtures/config.json' }
  let(:config_repo) { __dir__ + '/fixtures/config' }
  let(:repo) { SecureMirror::GitRepo.new(config_repo) }
  let(:setup) { SecureMirror::Setup.new(config, repo, logger) }
  let(:logger) { Logger.new(STDOUT) }

  before do
    FakeFS::FileSystem.clone(config_filename)
    FakeFS::FileSystem.clone(config_repo)
  end

  context 'policy setup' do
    before do
      config[:policy_definition] = nil
      config[:policy_class] = nil
    end

    it 'gets a default policy class when none is defined in config' do
      expect(setup.policy_class).to be SecureMirror::DefaultPolicy
    end
  end

  context 'client setup' do
    it 'sets up and returns a client based on config (github)' do
      expect(setup.client).to be
    end
  end

  context 'client setup with an unsupported config' do
    let(:config_repo) { __dir__ + '/fixtures/unsupported-config' }
    let(:repo) { SecureMirror::GitRepo.new(config_repo) }
    let(:setup) { SecureMirror::Setup.new(config, repo, logger) }

    it 'does not create a client for an unsupported config' do
      expect(setup.client).not_to be
    end
  end
end
