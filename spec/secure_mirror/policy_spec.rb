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

RSpec.describe SecureMirror::Policy, '#unit' do
  let(:config) do
    JSON.parse(File.read(__dir__ + '/fixtures/config.json'),
               symbolize_names: true)
  end
  let(:repo) { SecureMirror::GitRepo.new(__dir__ + '/fixtures/config') }
  let(:logger) { Logger.new(STDOUT) }
  let(:policy) do
    SecureMirror::Policy.new(config, phase, nil, repo, logger)
  end

  context 'interface' do
    let(:expected_hook_args) do
      [
        {
          :current_sha=>"refs/dev",
          :future_sha=>"0000000000000000000000000000000000000000",
          :ref_name=>"1212121212121212121212121212121212121212"
        }
      ]
    end

    context 'phase is pre-receive' do
      let(:phase) { 'pre-receive' }

      it '#evaluate returns a success code' do
        expect(policy.evaluate).to eq SecureMirror::Codes::OK
      end

      it 'can access the hook_args' do
        expect(policy.hook_args).to eq expected_hook_args
      end
    end

    context 'phase is update' do
      let(:phase) { 'update' }

      it '#evaluate returns a success code' do
        expect(policy.evaluate).to eq SecureMirror::Codes::OK
      end
    end

    context 'phase is post-receive' do
      let(:phase) { 'post-receive' }

      it '#evaluate returns a success code' do
        expect(policy.evaluate).to eq SecureMirror::Codes::OK
      end

      it 'can access the hook_args' do
        expect(policy.hook_args).to eq expected_hook_args
      end
    end
  end
end
