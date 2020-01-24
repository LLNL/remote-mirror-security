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

require 'inifile'
require 'date'
require 'repo'

RSpec.describe Repo, '#init' do
  context 'creates a basic repo object' do
    it 'initializes with a git config ini file' do
      hook_args = {
        repo_name: 'foo',
        ref_name: '/refs/head/bar',
        current_sha: '0000000000000000000000000000000000000000',
        future_sha: '6dcb09b5b57875f334f61aebed695e2e4193db5e'
      }
      repo = Repo.new(hook_args)
      expect(repo)
    end
  end
end
