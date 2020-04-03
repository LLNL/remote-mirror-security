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

require 'ostruct'
require 'logger'
require 'policy'
require 'git_repo'

ARGV = %w[
  ref
  0000000000000000000000000000000000000000
  1212121212121212121212121212121212121212
].freeze

RSpec.describe SecureMirror::Policy, '#unit' do
  before(:each) do
    @config = JSON.parse(File.read(__dir__ + '/fixtures/config.json'),
                         symbolize_names: true)
    @repo = SecureMirror::GitRepo.new(__dir__ + '/fixtures/config')
    @logger = Logger.new(STDOUT)
    @policy = SecureMirror::Policy.new(@config, 'pre-receive', nil, @repo,
                                       @logger)
  end

  context 'interface' do
    it 'responds to pre-receive' do
      @policy = SecureMirror::Policy.new(@config, 'pre-receive', nil, @repo,
                                         @logger)
      expect(@policy.evaluate).to eq SecureMirror::Codes::OK
    end

    it 'responds to update' do
      @policy = SecureMirror::Policy.new(@config, 'update', nil, @repo, @logger)
      expect(@policy.evaluate).to eq SecureMirror::Codes::OK
    end

    it 'responds to post-receive' do
      @policy = SecureMirror::Policy.new(@config, 'post-receive', nil, @repo,
                                         @logger)
      expect(@policy.evaluate).to eq SecureMirror::Codes::OK
    end
  end
end
