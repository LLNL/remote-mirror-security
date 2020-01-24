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
require 'logger'
require 'mirror_security'
require 'repo'
require 'collaborator'
require 'commit'
require 'comment'

class MockRepo < Repo
  def protected_branch?
    @branch_protected
  end

  attr_accessor :signoff_body
  attr_accessor :hook_args
  attr_accessor :collaborators
  attr_accessor :current_commit
  attr_accessor :future_commit
  attr_accessor :comments
  attr_accessor :trusted_org
  attr_accessor :branch_protected

  def initialize
    # defaults to vetted changes in an unprotected branch
    @logger = Logger.new(STDOUT)
    @signoff_body = 'lgtm'
    @hook_args = {
      ref_name: '/refs/head/foo',
      current_sha: '0000000000000000000000000000000000000000',
      future_sha: '6dcb09b5b57875f334f61aebed695e2e4193db5e'
    }
    @collaborators = {}
    @collaborators['foo'] = Collaborator.new('foo', true)
    @org_members = @collaborators
    @commits = {}
    @commits[@hook_args[:current_sha]] = Commit.new(
      '0000000000000000000000000000000000000000',
      '2011-01-14T16:00:49Z'
    )
    @commits[@hook_args[:future_sha]] = Commit.new(
      '6dcb09b5b57875f334f61aebed695e2e4193db5e',
      '2011-04-14T16:00:49Z'
    )
    @comments = [Comment.new('foo', 'LGTM', Time.now.to_s)]
    @trusted_org = 'FooOrg'
    @branch_protected = false
  end
end

RSpec.describe MirrorSecurity, '#init' do
  before(:each) do
    @mock_repo = MockRepo.new
  end

  context 'trusted collaborator' do
    it 'vets changes' do
      future_sha = @mock_repo.hook_args[:future_sha]
      expect(@mock_repo.vetted_change?(future_sha)).to be true
    end

    it 'blocks unvetted changes' do
      future_sha = @mock_repo.hook_args[:future_sha]
      comments = [Comment.new('foo', 'does not LGTM', Time.now.to_s)]
      @mock_repo.comments = comments
      expect(@mock_repo.vetted_change?(future_sha)).to be false
    end

    it 'does not vet for earlier comments' do
      future_sha = @mock_repo.hook_args[:future_sha]
      commit = Commit.new(future_sha, Time.now.to_s)
      comments = [Comment.new('foo', 'LGTM', '2011-04-14T16:00:49Z')]
      @mock_repo.comments = comments
      @mock_repo.future_commit = commit
      expect(@mock_repo.vetted_change?(future_sha)).to be false
    end

    it 'does not vet when there are no comments' do
      future_sha = @mock_repo.hook_args[:future_sha]
      @mock_repo.comments = []
      expect(@mock_repo.vetted_change?(future_sha)).to be false
    end
  end

  context 'trusted changes' do
    it 'can determine when changes are trusted' do
      expect(@mock_repo.trusted_change?).to be true
    end

    it 'trusts unvetted changes in protected branches' do
      @mock_repo.branch_protected = true
      @mock_repo.comments = []
      expect(@mock_repo.trusted_change?).to be true
    end

    it 'trusts vetted changes from unprotected branches' do
      future_commit = Commit.new(
        '6dcb09b5b57875f334f61aebed695e2e4193db5e',
        '2011-04-14T16:00:49Z'
      )
      @mock_repo.branch_protected = false
      @mock_repo.future_commit = future_commit
      expect(@mock_repo.trusted_change?).to be true
    end

    it 'does not trust unvetted changes from unprotected branches' do
      @mock_repo.branch_protected = false
      @mock_repo.comments = []
      expect(@mock_repo.trusted_change?).to be false
    end
  end
end

