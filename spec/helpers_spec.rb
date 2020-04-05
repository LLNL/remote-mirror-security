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

require 'helpers'

RSpec.describe SecureMirror, '#unit' do
  before(:each) do
  end

  context 'http methods' do
    it 'performs a basic get request' do
      VCR.use_cassette('lc_get') do
        resp = SecureMirror.http_get('https://lc.llnl.gov')
        expect(resp.code).to eq '302'
        expect(resp.body).not_to be nil
      end
    end
  end
end
