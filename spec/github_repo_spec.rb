# frozen_string_literal: true

require 'set'
require 'octokit'
require 'ostruct'
require 'github_repo'

ACCESS_TOKEN = 'TOKEN_GOES_HERE'.freeze

RSpec.describe GitHubRepo, '#init' do
  before(:each) do
    @hook_args = {
      repo_name: 'LLNL/Umpire',
      ref_name: '/refs/head/backtrace',
      current_sha: '323c557025586778867c4574698bca8df760c2b7',
      future_sha: 'b48659a8c2b6555b7a6299fbddda0fef6adf7105'
    }
    @client = Octokit::Client.new(per_page: 1000)
  end

  context 'creates a GitHub repo object' do
    it 'trusts changes to protected branches' do
      @hook_args[:ref_name] = '/refs/head/develop'
      allow(@client).to receive(:commit_branches) {
        [OpenStruct.new(name: 'develop', protected: true)]
      }
      allow(@client).to receive(:org_members) do |org_name, hash|
        if hash
          [{ login: 'foo' }]
        else
          [
            { login: 'mcfadden8' },
            { login: 'davidbeckingsale' }
          ]
        end
      end
      allow(@client).to receive(:collabs) {
        [
          { login: 'mcfadden8' },
          { login: 'davidbeckingsale' }
        ]
      }
      VCR.use_cassette('github_repo_init') do
        repo = GitHubRepo.new(
          @hook_args,
          clients: { main: @client },
          trusted_org: 'LLNL'
        )
        expect(repo)
        expect(repo.vetted_change?(@hook_args[:future_sha])).to be false
        expect(repo.trusted_change?).to be true
      end
    end

    it 'trusts vetted changes' do
      allow(@client).to receive(:org_members) do |org_name, hash|
        if hash
          [{ login: 'foo' }]
        else
          [
            { login: 'mcfadden8' },
            { login: 'davidbeckingsale' }
          ]
        end
      end
      allow(@client).to receive(:collabs) {
        [
          { login: 'mcfadden8' },
          { login: 'davidbeckingsale' }
        ]
      }
      VCR.use_cassette('github_repo_init') do
        repo = GitHubRepo.new(
          @hook_args,
          clients: { main: @client },
          trusted_org: 'LLNL',
          signoff_body: '@davidbeckingsale, this is now ready for review.  Bamboo tests all pass.'
        )
        expect(repo)
        expect(repo.vetted_change?(@hook_args[:future_sha])).to be true
        expect(repo.trusted_change?).to be true
      end
    end

    it 'fails if a user has 2FA disabled' do
      allow(@client).to receive(:org_members) {
        [{ login: 'mcfadden8' }]
      }
      allow(@client).to receive(:collabs) {
        [
          { login: 'mcfadden8' },
          { login: 'davidbeckingsale' }
        ]
      }
      VCR.use_cassette('github_repo_init') do
        repo = GitHubRepo.new(
          @hook_args,
          clients: { main: @client },
          trusted_org: 'LLNL',
          signoff_body: '@davidbeckingsale, this is now ready for review.  Bamboo tests all pass.'
        )
        expect(repo)
        expect(repo.vetted_change?(@hook_args[:future_sha])).to be false
        expect(repo.trusted_change?).to be false
      end
    end

    it 'fails if a user is not in the organization' do
      allow(@client).to receive(:org_members) {
        [{ login: 'foo' }]
      }
      allow(@client).to receive(:collabs) {
        [
          { login: 'mcfadden8' },
          { login: 'davidbeckingsale' }
        ]
      }
      VCR.use_cassette('github_repo_init') do
        repo = GitHubRepo.new(
          @hook_args,
          clients: { main: @client },
          trusted_org: 'LLNL',
          signoff_body: '@davidbeckingsale, this is now ready for review.  Bamboo tests all pass.'
        )
        expect(repo)
        expect(repo.vetted_change?(@hook_args[:future_sha])).to be false
        expect(repo.trusted_change?).to be false
      end
    end
  end
end
