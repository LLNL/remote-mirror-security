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

RSpec.describe SecureMirror, '#unit' do
  context 'http methods' do
    before do
      stub_request(:get, /lc.llnl.gov/).
        with(headers: {'Accept'=>'*/*', 'User-Agent'=>'Ruby'}).
        to_return(status: 302, body: nil, headers: {})
    end

    it 'performs a basic get request' do
      resp = SecureMirror.http_get('https://lc.llnl.gov')
      expect(resp.code).to eq '302'
      expect(resp.body).not_to be nil
    end
  end

  describe '.class_from_string' do
    it 'returns a constant from a klass string' do
      github_client = SecureMirror::GitHubMirrorClient
      expect(SecureMirror.class_from_string(github_client.to_s)).to be(github_client)
    end
  end
end
