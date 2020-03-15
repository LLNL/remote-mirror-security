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

require 'collaborator'

RSpec.describe SecureMirror::Collaborator, '#init' do
  context 'creates a basic collaborator object' do
    it 'initializes with a name and whether or not theyre trusted' do
      collab = SecureMirror::Collaborator.new('foo', true)
      expect(collab.name).to be_truthy
      expect(collab.trusted)
    end
  end
end
