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

RSpec.describe SecureMirror::Collaborator, '#init' do
  context 'creates a basic collaborator object' do
    let(:collab) { SecureMirror::Collaborator.new('foo', true) }

    it 'initializes with a name and whether or not theyre trusted' do
      expect(collab.name).to be_truthy
      expect(collab.trusted)
    end

    it 'can be represented as a hash' do
      expected = { klass: 'SecureMirror::Collaborator',
                   name: 'foo',
                   trusted: true }
      expect(collab.as_json). to eq(expected)
    end

    it 'can be represented as JSON' do
      result = JSON.parse(collab.to_json, symbolize_names: true)
      expect(result).to eq collab.as_json
    end

    it 'can be loaded from a JSON object' do
      collaborator = SecureMirror::Collaborator.from_json(collab.as_json)
      expect(collaborator.name).to be_truthy
      expect(collab.trusted)
    end
  end
end
