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

def read_perms
  { admin: false, push: false, pull: true }
end

def write_perms
  { admin: true, push: true, pull: true }
end

def member_with_read
  { login: 'thomas', permissions: read_perms }
end

def members
  [
    member_with_read,
    { login: 'mcfadden8', permissions: write_perms },
    { login: 'davidbeckingsale', permissions: write_perms }
  ]
end

def thomas
  [{ login: 'thomas', permissions: write_perms }]
end

def verify_members(members)
  members.each do |name, member|
    expect(name).to be
    expect(member.name).to eq name
    expect(member.trusted).to be(true).or be(false)
  end
end

RSpec.describe SecureMirror::GitHubMirrorClient, '#client' do
  include FakeFS::SpecHelpers

  let(:org) { 'foo' }
  let(:repo) { 'bar' }
  let(:token) { 'FOO' }
  let(:sha) { '1111111111111111111111111111111111111111' }
  let(:alt_tokens) do
    { bar: 'BAR' }
  end
  let(:config) do
    JSON.parse(File.read(config_filename),
               symbolize_names: true)
  end
  let(:mirror_client) do
    SecureMirror::GitHubMirrorClient.new(
      token,
      alt_tokens: alt_tokens,
      config: config,
    )
  end
  let(:config_filename) { __dir__ + '/fixtures/config.json' }

  before do
    FakeFS::FileSystem.clone(config_filename)
  end

  context 'exposes a simplified subset of data from GitHub' do
    it 'gathers organization members' do
      allow(mirror_client.client).to receive(:org_members) do |_, hash|
        hash ? thomas : members
      end

      members = mirror_client.org_members(org: org)

      verify_members(members)
    end

    it 'gathers repo collaborators' do
      allow(mirror_client.client).to receive(:collabs) { members }
      collabs = mirror_client.collaborators(repo)
      collabs.each do |name, collab|
        expect(collab.name).not_to be nil
        expect(collab.name).to eq name
        expect(collab.trusted).to eq false
      end
    end

    it 'only considers collaborators with repo write access' do
      allow(mirror_client.client).to receive(:collabs) { members }
      collabs = mirror_client.collaborators(repo)
      expect(collabs.any? { |k, _| member_with_read[:login] == k }).to be false
    end

    it 'has an empty list of collaborators when unauthorized' do
      allow(mirror_client.client).to receive(:collabs) { raise Octokit::Forbidden }

      collabs = mirror_client.collaborators(repo)
      expect(collabs.empty?).to be true
    end

    it 'gathers review comments' do
      # comments = mirror_client.review_comments(repo, sha)
      # expect(comments).to eq []
    end

    it 'gathers commit data' do
      allow(mirror_client.client).to receive(:commit) do
        OpenStruct.new(commit:
          OpenStruct.new(committer:
            OpenStruct.new(date: Time.now)))
      end
      allow(mirror_client.client).to receive(:commit_branches) do
        [OpenStruct.new(name: 'foo', protected: true)]
      end

      commit = mirror_client.commit(repo, sha)
      expect(commit.sha).to eq sha
      expect(commit.date).not_to be nil
      expect(commit.branches).to be_an(Array)
      expect(commit.protected_branch?('foo')).to be true
    end

    it 'can use an alternative client when other credentials are needed' do
      allow(mirror_client.client).to receive(:org_members) do
        raise Octokit::Unauthorized
      end

      allow(mirror_client.alt_clients[:bar]).to receive(:org_members) do
        members
      end

      expect do
        mirror_client.org_members(org: org)
      end.to raise_error(SecureMirror::ClientUnauthorized)

      members = mirror_client.org_members(org: org, client_name: 'bar')
      verify_members(members)
    end
  end
end

RSpec.describe SecureMirror::GitHubMirrorClient, '#cache' do
  include FakeFS::SpecHelpers

  let(:org) { 'foo' }
  let(:repo) { 'bar' }
  let(:token) { 'FOO' }
  let(:sha) { '1111111111111111111111111111111111111111' }
  let(:alt_tokens) do
    { bar: 'BAR' }
  end
  let(:cache_dir) { '/tmp/secure-mirror-tests' }
  let(:config_filename) { __dir__ + '/fixtures/config.json' }
  let(:config) do
    JSON.parse(File.read(config_filename),
               symbolize_names: true)
  end
  let(:github_client) do
    SecureMirror::GitHubMirrorClient.new(
      token,
      alt_tokens: alt_tokens,
      config: config[:repo_types][:github]
    )
  end
  let(:mirror_client) do
    SecureMirror::CachingMirrorClient.new(
      github_client,
      cache_dir: cache_dir
    )
  end

  before(:each) do
    FakeFS::FileSystem.clone(config_filename)
    FileUtils.mkdir_p cache_dir
  end

  after(:each) do
    FileUtils.rm_rf cache_dir
  end

  context 'the client can have calls cached generically' do
    it 'does not cache calls for client config' do
      mirror_client.config
      expect(Dir.empty?(cache_dir)).to be true
    end

    it 'can cache results for repeated calls to a method' do
      allow(github_client.client).to receive(:org_members) do |_, hash|
        hash ? thomas : members
      end
      args = { org: org }
      mirror_client.org_members(**args)
      key = mirror_client.cache_key('org_members', [args].to_s)
      expect(File.exist?(mirror_client.cache_file(key))).to be true

      members = mirror_client.org_members(org: org, expires: 5 * 60)
      # ONE call to org_members actually requires TWO api calls: one to find
      # all non-2fa members then one for all members of the org
      expect(github_client.client).to have_received(:org_members).twice
      verify_members(members)
    end
  end
end
