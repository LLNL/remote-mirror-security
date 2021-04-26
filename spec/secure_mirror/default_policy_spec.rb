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

RSpec.describe SecureMirror::DefaultPolicy, '#unit' do
  let(:trusted_member) { 'foo' }
  let(:untrusted_member) { 'bar' }
  let(:org_members) do
    {
      'foo' => SecureMirror::Collaborator.new(trusted_member, true),
      'bar' => SecureMirror::Collaborator.new('bar', false)
    }
  end
  let(:collaborators) do
    {
      'foo' => SecureMirror::Collaborator.new(trusted_member, false)
    }
  end
  let(:branches) do
    [{ name: 'dev', protection: true }]
  end
  let(:commit) do
    SecureMirror::Commit.new(ARGV[2],
                             '2011-04-14T16:00:49Z',
                             branches)
  end
  let(:untrusted_branch) { [{ name: 'feature', protection: false }] }
  let(:untrusted_commit) do
    SecureMirror::Commit.new(ARGV[2],
                             '2011-04-14T16:00:49Z',
                             untrusted_branch)
  end
  let(:comment_before_commit) do
    [SecureMirror::Comment.new(trusted_member, 'lgtm', '2011-04-13T16:00:49Z')]
  end
  let(:untrusted_comment) do
    [SecureMirror::Comment.new(trusted_member, 'lbtm', Time.now)]
  end
  let(:untrusted_commenter) do
    [SecureMirror::Comment.new(untrusted_member, 'lbtm',
                               '2011-04-13T16:00:49Z')]
  end
  let(:review_comments) do
    untrusted_commenter + untrusted_comment + comment_before_commit +
      [SecureMirror::Comment.new(trusted_member, 'lgtm', Time.now)]
  end
  let(:client) do
    instance_double('MirrorClient', org_members: org_members,
                                    collaborators: collaborators,
                                    review_comments: review_comments,
                                    commit: commit,
                                    config: config[:repo_types][:github])
  end
  let(:config) do
    JSON.parse(File.read(__dir__ + '/fixtures/config.json'),
               symbolize_names: true)
  end
  let(:logger) { Logger.new(STDOUT) }
  let(:repo) { SecureMirror::GitRepo.new(__dir__ + '/fixtures/config') }
  let(:policy) do
    SecureMirror::DefaultPolicy.new(config, phase, client, repo, logger)
  end
  let(:phase) { 'update' }

  describe '#creation' do
    context 'initialize' do
      it 'raises an error when client is nil' do
        expect do
          SecureMirror::DefaultPolicy.new(config, phase, nil, repo, logger)
        end.to raise_error StandardError
      end
    end
  end

  describe '#collabs_trusted?' do
    context 'when collaborators include untrusted org members' do
      let(:collaborators) { org_members }

      it 'returns false' do
        expect(policy.collabs_trusted?).to be false
      end
    end

    context 'when collaborators are trusted' do
      it 'returns true' do
        expect(policy.collabs_trusted?).to be true
      end
    end

    context 'when we cannot get info back from the client' do
      before do
        allow(client).to receive(:collaborators)
          .and_raise SecureMirror::ClientUnauthorized
      end

      it 'returns false' do
        expect(policy.collabs_trusted?).to be false
      end
    end
  end

  describe '#signoff?' do
    let(:config_signoff_bodies) { client.config[:signoff_bodies] }

    it 'should have a hash of signoff_bodies' do
      signoff_bodies = policy.signoff_bodies
      expect(signoff_bodies).to be_a(Hash)
    end

    it 'should be case insensitive' do
      signoff_message = config_signoff_bodies[0]
      capitalized_signoff_message = signoff_message.upcase
      expect(policy.signoff?(signoff_message))
        .to eq(policy.signoff?(capitalized_signoff_message))
    end

    it 'returns true when the message is a signoff' do
      signoff_message = config_signoff_bodies[0]
      expect(policy.signoff?(signoff_message)).to be true
    end

    it 'returns false when the message is not a signoff' do
      expect(policy.signoff?('i dont like this commit')).to be false
    end
  end

  describe '#vetted_by' do
    context 'signoff commenter is a trusted member' do
      it 'is considered vetted' do
        expect(policy.vetted_by).not_to be nil
        expect(policy.vetted_by.commenter).to eq trusted_member
      end
    end

    context 'signoff commenter is an untrusted user' do
      let(:review_comments) { untrusted_commenter }

      it 'returns nil' do
        expect(policy.vetted_by).to be nil
      end
    end

    context 'the review comment is not an approval' do
      let(:review_comments) { untrusted_comment }

      it 'returns nil' do
        expect(policy.vetted_by).to be nil
      end
    end

    context 'the trusted comment is before the commit' do
      let(:review_comments) { comment_before_commit }

      it 'returns nil' do
        expect(policy.vetted_by).to be nil
      end
    end
  end

  describe '#evaluate' do
    context 'phase is pre-receive' do
      let(:phase) { 'pre-receive' }

      it 'responds with success code' do
        expect(policy.evaluate).to eq SecureMirror::Codes::OK
      end
    end

    context 'phase is update' do
      context 'all collabs trusted' do
        let(:review_comments) { [] }

        it 'responds with success code' do
          expect(policy.evaluate).to eq SecureMirror::Codes::OK
        end
      end

      context 'vetted by a trusted user' do
        let(:collaborators) { org_members }
        let(:commit) { untrusted_commit }

        it 'responds with success code' do
          expect(policy.evaluate).to eq SecureMirror::Codes::OK
        end
      end

      context 'not all collabs trusted but branches protected' do
        let(:review_comments) { [] }
        let(:collaborators) { org_members }

        it 'responds with denial code' do
          expect(policy.evaluate).to eq SecureMirror::Codes::DENIED
        end
      end
    end
  end
end
