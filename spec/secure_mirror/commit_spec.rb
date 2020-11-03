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

RSpec.describe SecureMirror::Commit, '#init' do
  context 'creates a basic commit object' do
    let(:commit) { SecureMirror::Commit.new(sha, date, branches) }
    let(:branches) { [] }
    let(:sha) { '6dcb09b5b57875f334f61aebed695e2e4193db5e' }
    let(:date) { '2011-04-14T16:00:49Z' }

    it 'houses only basic, necessary info' do
      expect(commit.sha).to eq sha
      expect(commit.date).to be < Time.now
    end

    it 'can be represented as a hash' do
      expect(commit.as_json).to eq({
        :klass=>"SecureMirror::Commit", 
        :sha=>sha,
        :branches=>branches, 
        :date => Time.utc(2011,4,14,16,0,49)
      })
    end

    it 'can be represented as JSON' do
      expect(JSON.parse(commit.to_json, symbolize_names: true)).to eq ({
        :klass=>"SecureMirror::Commit", 
        :sha=>sha,
        :branches=>branches, 
        :date => Time.utc(2011,4,14,16,0,49).to_s
      })
    end

    it 'can be loaded from a JSON object' do
      parsed_commit = SecureMirror::Commit.from_json(commit.as_json)
      expect(parsed_commit.sha).to eq sha
      expect(parsed_commit.branches).to eq branches
      expect(parsed_commit.date).to be_a(Time)
    end

    describe '#protected' do
      let(:branches) do
        [
          { name: 'banana', protection: true },
          { name: 'apple', protection: false }
        ]
      end

      context 'when a branch is protected' do
        it 'returns true' do
          expect(commit.protected_branch?('banana')).to eq(true)
        end
      end

      context 'when a branch is not protected' do
        it 'returns false' do
          expect(commit.protected_branch?('apple')).to eq(false)
        end
      end

      context 'when a branch name does not match the branches given' do
        it 'returns false' do
          expect(commit.protected_branch?('orange')).to eq(false)
        end
      end
    end
  end
end
