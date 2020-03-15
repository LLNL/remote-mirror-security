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
require 'comment'

RSpec.describe SecureMirror::Comment, '#init' do
  context 'creates a basic comment object' do
    it 'houses only basic, necessary info' do
      comment = SecureMirror::Comment.new('me', 'hello', '2011-04-14T16:00:49Z')
      expect(comment.body).to eq 'hello'
      expect(comment.date).to be < Time.now
    end
  end
end
