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

RSpec.describe SecureMirror::Comment, '#init' do
  context 'creates a basic comment object' do
    let(:comment) { SecureMirror::Comment.new('me', 'hello', '2011-04-14T16:00:49Z') }

    it 'houses only basic, necessary info' do
      expect(comment.body).to eq 'hello'
      expect(comment.date).to be < Time.now
    end

    it 'can be represented as a hash' do
      expect(comment.as_json).to eq({
        :klass=>"SecureMirror::Comment", 
        :commenter=>"me", 
        :body=>"hello", 
        :date => Time.utc(2011,4,14,16,0,49)
      })
    end

    it 'can be represented as JSON' do
      expect(JSON.parse(comment.to_json, symbolize_names: true)).to eq ({
        :klass=>"SecureMirror::Comment", 
        :commenter=>"me", 
        :body=>"hello", 
        :date => Time.utc(2011,4,14,16,0,49).to_s
      })
    end

    it 'can be loaded from a JSON object' do
      parsed_comment = SecureMirror::Comment.from_json(comment.as_json)
      expect(parsed_comment.body).to eq 'hello'
      expect(parsed_comment.date).to be_a(Time)
    end

    it 'can handle a variety of time formats' do
      expect(SecureMirror::Comment.new('me', 'hello', nil).date).to eq nil
      expect(SecureMirror::Comment.new('me', 'hello', Date.new(2016, 11, 4)).date).to be_a(Time)
      expect(SecureMirror::Comment.new('me', 'hello', Time.new(2016, 11, 4)).date).to be_a(Time)
      expect(SecureMirror::Comment.new('me', 'hello', '2011-04-14T16:00:49Z').date).to be_a(Time)
    end
  end
end
