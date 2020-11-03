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

RSpec.describe SecureMirror::GitRepo, '#init' do
  let(:empty_config) { '' }
  let(:git_config_file) { __dir__ + '/fixtures/github-config' }
  let(:non_mirror_config_file) { __dir__ + '/fixtures/non-mirror-config' }
  let(:unsupported_git_config_file) { __dir__ + '/fixtures/unsupported-config' }

  context 'creates a git repo object' do
    it 'says it is a new repo if no config exists' do
      repo = SecureMirror::GitRepo.new(empty_config)
      expect(repo.new_repo?).to be true
    end

    it 'populates info about a repo on disk' do
      repo = SecureMirror::GitRepo.new(git_config_file)
      expect(repo.name).to eq 'LLNL/Umpire'
      expect(repo.remote?).to be true
      expect(repo.new_repo?).to be false
      expect(repo.misconfigured?).to be false
    end
  end
end
