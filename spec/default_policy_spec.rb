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

require 'ostruct'
require 'logger'
require 'mirror_client'
require 'default_policy'
require 'git_repo'
require 'collaborator'
require 'commit'
require 'comment'

ARGV = %w[
  refs/dev
  0000000000000000000000000000000000000000
  1212121212121212121212121212121212121212
].freeze

RSpec.describe SecureMirror::DefaultPolicy, '#unit' do
  def trusted_member
    'foo'
  end

  def untrusted_member
    'bar'
  end

  def org_members
    {
      'foo' => SecureMirror::Collaborator.new(trusted_member, true),
      'bar' => SecureMirror::Collaborator.new('bar', false)
    }
  end

  def collaborators
    {
      'foo' => SecureMirror::Collaborator.new(trusted_member, false)
    }
  end

  def branches
    [{ name: 'dev', protection: true }]
  end

  def commit
    SecureMirror::Commit.new(ARGV[2], '2011-04-14T16:00:49Z', branches)
  end

  def untrusted_branch
    [{ name: 'feature', protection: false }]
  end

  def untrusted_commit
    SecureMirror::Commit.new(ARGV[2], '2011-04-14T16:00:49Z', untrusted_branch)
  end

  def comment_before_commit
    [SecureMirror::Comment.new(trusted_member, 'lgtm', '2011-04-13T16:00:49Z')]
  end

  def untrusted_comment
    [SecureMirror::Comment.new(trusted_member, 'lbtm', Time.now)]
  end

  def untrusted_commenter
    [SecureMirror::Comment.new(untrusted_member, 'lbtm',
                               '2011-04-13T16:00:49Z')]
  end

  def review_comments
    untrusted_commenter + untrusted_comment + comment_before_commit +
      [SecureMirror::Comment.new(trusted_member, 'lgtm', Time.now)]
  end

  def working_client
    client = instance_double('MirrorClient')
    allow(client).to receive(:org_members).and_return org_members
    allow(client).to receive(:collaborators).and_return collaborators
    allow(client).to receive(:review_comments).and_return review_comments
    allow(client).to receive(:commit).and_return commit
    client
  end

  before(:each) do
    @config = JSON.parse(File.read(__dir__ + '/fixtures/config.json'),
                         symbolize_names: true)
    @repo = SecureMirror::GitRepo.new(__dir__ + '/fixtures/config')
    @logger = Logger.new(STDOUT)
    @client = working_client
    allow(@client).to receive(:config).and_return @config[:repo_types][:github]
  end

  context 'interface' do
    it 'responds to pre-receive' do
      @policy = SecureMirror::DefaultPolicy.new(@config, 'pre-receive', @client,
                                                @repo, @logger)
      expect(@policy.evaluate).to eq SecureMirror::Codes::OK
    end

    it 'determines if a set of collaborators are trusted' do
      @policy = SecureMirror::DefaultPolicy.new(@config, 'update', @client,
                                                @repo, @logger)
      expect(@policy.collabs_trusted?).to be true

      # not all org members are trusted
      allow(@client).to receive(:collaborators).and_return org_members
      @policy = SecureMirror::DefaultPolicy.new(@config, 'update', @client,
                                                @repo, @logger)
      expect(@policy.collabs_trusted?).to be false

      # show as untrusted if we can't get info back from the client
      allow(@client).to receive(:collaborators)
        .and_raise SecureMirror::ClientUnauthorized
      @policy = SecureMirror::DefaultPolicy.new(@config, 'update', @client,
                                                @repo, @logger)
      expect(@policy.collabs_trusted?).to be false
    end

    it 'tests if a message is a trusted sign-off expression' do
      @policy = SecureMirror::DefaultPolicy.new(@config, 'update', @client,
                                                @repo, @logger)
      signoff_bodies = @policy.signoff_bodies
      expect(signoff_bodies.is_a?(Hash)).to be true
      expect(@policy.signoff?(@client.config[:signoff_bodies][0])).to be true
      # should be case insensitive
      expect(@policy.signoff?(@client.config[:signoff_bodies][0].upcase))
        .to be true
      expect(@policy.signoff?('i dont like this commit')).to be false
    end

    it 'vets a trusted signoff message for a commit' do
      @policy = SecureMirror::DefaultPolicy.new(@config, 'update', @client,
                                                @repo, @logger)
      expect(@policy.vetted_by).not_to be nil
      expect(@policy.vetted_by.commenter).to eq trusted_member
    end

    it 'does not vet a commit from an untrusted user' do
      # untrusted user
      allow(@client).to receive(:review_comments)
        .and_return untrusted_commenter
      @policy = SecureMirror::DefaultPolicy.new(@config, 'update', @client,
                                                @repo, @logger)
      expect(@policy.vetted_by).to be nil
    end

    it 'does not vet a commit when the sign off is bad' do
      allow(@client).to receive(:review_comments)
        .and_return untrusted_comment
      @policy = SecureMirror::DefaultPolicy.new(@config, 'update', @client,
                                                @repo, @logger)
      expect(@policy.vetted_by).to be nil
    end

    it 'does not vet a commit when the trusted comment is before the commit' do
      allow(@client).to receive(:review_comments)
        .and_return comment_before_commit
      @policy = SecureMirror::DefaultPolicy.new(@config, 'update', @client,
                                                @repo, @logger)
      expect(@policy.vetted_by).to be nil
    end

    it 'allows changes when all collabs trusted and branches protected' do
      allow(@client).to receive(:review_comments).and_return []
      @policy = SecureMirror::DefaultPolicy.new(@config, 'update', @client,
                                                @repo, @logger)
      expect(@policy.evaluate).to eq SecureMirror::Codes::OK
    end

    it 'allows changes when vetted by a trusted user' do
      allow(@client).to receive(:collaborators).and_return org_members
      allow(@client).to receive(:commit).and_return untrusted_commit
      @policy = SecureMirror::DefaultPolicy.new(@config, 'update', @client,
                                                @repo, @logger)
      expect(@policy.evaluate).to eq SecureMirror::Codes::OK
    end

    it 'disallows changes when all collabs trusted but branches unprotected' do
      allow(@client).to receive(:review_comments).and_return []
      allow(@client).to receive(:commit).and_return untrusted_commit
      @policy = SecureMirror::DefaultPolicy.new(@config, 'update', @client,
                                                @repo, @logger)
      expect(@policy.evaluate).to eq SecureMirror::Codes::DENIED
    end

    it 'disallows changes if not all collabs trusted but branches protected' do
      allow(@client).to receive(:review_comments).and_return []
      allow(@client).to receive(:collaborators).and_return org_members
      @policy = SecureMirror::DefaultPolicy.new(@config, 'update', @client,
                                                @repo, @logger)
      expect(@policy.evaluate).to eq SecureMirror::Codes::DENIED
    end
  end
end
