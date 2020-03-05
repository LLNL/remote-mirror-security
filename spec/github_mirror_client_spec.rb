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
require 'fileutils'
require 'github_mirror_client'

def mock_members(org_name, hash)
  if hash
    [{ login: 'thomas' }]
  else
    [
      { login: 'thomas' },
      { login: 'mcfadden8' },
      { login: 'davidbeckingsale' }
    ]
  end
end

RSpec.describe GitHubMirrorClient, '#client' do
  before(:each) do
    @org = 'foo'
    @repo = 'bar'
    @token = 'FOO'
    @sha = '1111111111111111111111111111111111111111'
    @alt_tokens = {
      bar: 'BAR'
    }
    @mirror_client = GitHubMirrorClient.new(@token, alt_tokens: @alt_tokens)
  end

  context 'exposes a simplified subset of data from GitHub' do
    it 'gathers organization members' do
      allow(@mirror_client.client).to receive(:org_members) do |org_name, hash|
        mock_members(org_name, hash)
      end
      members = @mirror_client.org_members(@org)
      members.each do |name, member|
        expect(member.name).not_to be nil
        expect(member.name).to eq name
        expect(member.trusted).to eq !!member.trusted
      end
    end

    it 'gathers repo collaborators' do
      allow(@mirror_client.client).to receive(:collabs) do
        mock_members(nil, nil)
      end
      collabs = @mirror_client.collaborators(@repo)
      collabs.each do |name, collab|
        expect(collab.name).not_to be nil
        expect(collab.name).to eq name
        expect(collab.trusted).to eq false
      end
    end

    it 'gathers commit data' do
      allow(@mirror_client.client).to receive(:commit) do
        OpenStruct.new(commit:
          OpenStruct.new(author:
            OpenStruct.new(date: Time.now)))
      end
      allow(@mirror_client.client).to receive(:commit_branches) do
        [OpenStruct.new(name: 'foo', protected: true)]
      end

      commit = @mirror_client.commit(@repo, @sha)
      expect(commit.sha).to eq @sha
      expect(commit.date).not_to be nil
      expect(commit.branches.is_a?(Array)).to be true
      expect(commit.protected_branch?('foo')).to be true
    end

    it 'can use an alternative client when other credentials are needed' do
      allow(@mirror_client.client).to receive(:org_members) do
        raise Octokit::Unauthorized
      end

      allow(@mirror_client.alt_clients[:bar]).to receive(:org_members) do
        mock_members(nil, nil)
      end

      expect do
        @mirror_client.org_members(@org)
      end.to raise_error(MirrorClientUnauthorized)

      members = @mirror_client.org_members(@org, client_name: 'bar')
      members.each do |name, member|
        expect(member.name).not_to be nil
        expect(member.name).to eq name
        expect(member.trusted).to eq !!member.trusted
      end
    end
  end
end

RSpec.describe GitHubMirrorClient, '#cache' do
  before(:all) do
  end

  before(:each) do
    @org = 'foo'
    @repo = 'bar'
    @token = 'FOO'
    @sha = '1111111111111111111111111111111111111111'
    @alt_tokens = {
      bar: 'BAR'
    }
    @cache_dir = '/tmp/secure-mirror-tests'
    FileUtils.mkdir_p @cache_dir
    @github_client = GitHubMirrorClient.new(@token, alt_tokens: @alt_tokens)
    @mirror_client = CachingMirrorClient.new(
      @github_client,
      cache_dir: @cache_dir
    )
  end

  after(:each) do
    FileUtils.rm_rf @cache_dir
  end

  context 'the client can have calls cached generically' do
    it 'can cache results for repeated calls to a method' do
      allow(@github_client.client).to receive(:org_members) do |org_name, hash|
        mock_members(org_name, hash)
      end
      @mirror_client.org_members(@org)
      key = @mirror_client.cache_key('org_members', [@org].to_s)
      expect(File.exist?(@mirror_client.cache_file(key))).to be true

      members = @mirror_client.org_members(@org, expires: 5 * 60)
      # ONE call to org_members actually requires TWO api calls: one to find
      # all non-2fa members then one for all members of the org
      expect(@github_client.client).to have_received(:org_members).twice
      members.each do |name, member|
        expect(member.name).not_to be nil
        expect(member.name).to eq name
        expect(member.trusted).to eq !!member.trusted
      end
    end
  end
end
