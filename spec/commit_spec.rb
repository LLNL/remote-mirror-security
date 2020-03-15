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

require 'time'
require 'commit'

RSpec.describe SecureMirror::Commit, '#init' do
  context 'creates a basic commit object' do
    it 'houses only basic, necessary info' do
      commit = SecureMirror::Commit.new(
        '6dcb09b5b57875f334f61aebed695e2e4193db5e',
        '2011-04-14T16:00:49Z'
      )
      expect(commit.sha).to eq '6dcb09b5b57875f334f61aebed695e2e4193db5e'
      expect(commit.date).to be < Time.now
    end
  end
end
