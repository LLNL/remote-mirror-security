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

RSpec.describe SecureMirror::Policy, '#unit' do
  before(:each) do
    @logger = Logger.new(STDOUT)
    @policy = SecureMirror::Policy.new(nil, 'pre-receive', nil, nil, @logger)
  end

  context 'interface' do
    it 'responds to the three git hook phases' do
      @policy = SecureMirror::Policy.new(nil, 'pre-receive', nil, nil, @logger)
      expect(@policy.evaluate).to eq SecureMirror::Codes::OK
      @policy = SecureMirror::Policy.new(nil, 'update', nil, nil, @logger)
      expect(@policy.evaluate).to eq SecureMirror::Codes::OK
      @policy = SecureMirror::Policy.new(nil, 'post-receive', nil, nil, @logger)
      expect(@policy.evaluate).to eq SecureMirror::Codes::OK
    end
  end
end
