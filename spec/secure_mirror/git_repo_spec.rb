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

RSpec.describe SecureMirror::GitRepo, '#init' do
  let(:empty_config) { '' }
  let(:git_config) { 'github-config' }
  let(:git_config_file) { __dir__ + "/fixtures/#{git_config}" }
  let(:non_mirror_config_file) { __dir__ + '/fixtures/non-mirror-config' }
  let(:unsupported_git_config_file) { __dir__ + '/fixtures/unsupported-config' }
  let(:normal_repo_dir) { 'git-data/repositories/foo.git' }
  let(:hashed_repo_dir) { 'git-data/repositories/@hashed/6b/86/6b86b273ff34fce19.git' }
  let(:hashed_wiki_repo_dir) { 'git-data/repositories/@hashed/6b/86/6b86b273ff34fce19.wiki.git' }

  context 'creates a git repo object' do
    it 'says it is a new repo if no config exists' do
      repo = SecureMirror::GitRepo.new(empty_config)
      expect(repo.new_repo?).to be true
    end

    it 'populates info about a repo on disk' do
      repo = SecureMirror::GitRepo.new(git_config_file)
      expect(repo.name).to eq 'LLNL/Umpire'
      expect(repo.remote?).to be true
      expect(repo.new_repo?).to be false
      expect(repo.misconfigured?).to be false
    end

  end

  context 'introspects the repo' do
    let(:repo) { SecureMirror::GitRepo.new(git_config_file) }

    it 'determines when a repo is a wiki' do
      Dir.mktmpdir do |dir|
        repo_dir = File.join(dir, hashed_wiki_repo_dir)
        FileUtils.mkdir_p repo_dir
        FileUtils.cp(git_config_file, repo_dir)
        config = File.join(repo_dir, git_config)
        repo = SecureMirror::GitRepo.new(config)
        expect(repo.wiki?).to be true
      end
    end

    it 'determines when a repo is not a wiki' do
      Dir.mktmpdir do |dir|
        repo_dir = File.join(dir, hashed_repo_dir)
        FileUtils.mkdir_p repo_dir
        FileUtils.cp(git_config_file, repo_dir)
        config = File.join(repo_dir, git_config)
        repo = SecureMirror::GitRepo.new(config)
        expect(repo.wiki?).to be false
      end
    end

    it 'determines when a repo is part of a shard managed by hashing names' do
      Dir.mktmpdir do |dir|
        repo_dir = File.join(dir, hashed_repo_dir)
        FileUtils.mkdir_p repo_dir
        FileUtils.cp(git_config_file, repo_dir)
        config = File.join(repo_dir, git_config)
        repo = SecureMirror::GitRepo.new(config)
        expect(repo.hashed?).to be true
      end
    end

    it 'determines when a repo is managed as-is on disk' do
      Dir.mktmpdir do |dir|
        repo_dir = File.join(dir, normal_repo_dir)
        FileUtils.mkdir_p repo_dir
        FileUtils.cp(git_config_file, repo_dir)
        config = File.join(repo_dir, git_config)
        repo = SecureMirror::GitRepo.new(config)
        expect(repo.hashed?).to be false
      end
    end
  end
end
