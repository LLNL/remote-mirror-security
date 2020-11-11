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

RSpec.describe SecureMirror::MirrorClient, '#unit' do
  it 'calling org_members directly raises a NotImplementedError' do
    expect{ subject.org_members }.to raise_error(NotImplementedError)
  end

  it 'calling collaborators directly raises a NotImplementedError' do
    expect{ subject.collaborators('repo') }.to raise_error(NotImplementedError)
  end

  it 'calling commit directly raises a NotImplementedError' do
    expect{ subject.commit('repo', 'sha') }.to raise_error(NotImplementedError)
  end

  it 'calling branches directly raises a NotImplementedError' do
    expect{ subject.branches('repo', 'sha') }.to raise_error(NotImplementedError)
  end

  it 'calling review_comments directly raises a NotImplementedError' do
    expect{ subject.review_comments('repo', 'sha') }.to raise_error(NotImplementedError)
  end
end
