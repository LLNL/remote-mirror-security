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
  after(:each) do
    f = SecureMirror.mirrored_status_file
    File.unlink f if File.exist? f
  end

  context 'helpers' do
    it 'caches mirroring status to a known file' do
      expect(SecureMirror.cache_mirrored_status(true)).to be true
      expect(File.file?(SecureMirror.mirrored_status_file)).to be true
    end

    it 'does not create a file if the mirror status is false' do
      expect(SecureMirror.cache_mirrored_status(false)).to be false
      expect(File.file?(SecureMirror.mirrored_status_file)).to be false
    end

    it 'can remove cached mirror status' do
      SecureMirror.cache_mirrored_status(true)
      expect(SecureMirror.remove_mirrored_status).to be true
      expect(File.file?(SecureMirror.mirrored_status_file)).to be false
    end
  end
end