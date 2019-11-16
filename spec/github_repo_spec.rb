require 'set'
require 'octokit'
require 'github_repo'

ACCESS_TOKEN = 'TOKEN_GOES_HERE'.freeze

RSpec.describe GitHubRepo, '#init' do
  context 'creates a GitHub repo object' do
    it 'determines if a set of changes are trusted' do
      change_args = {
        ref_name: '/refs/head/foo',
        current_sha: 'd3bfb4ccafd7a4fa4e6f84396f83273ad45a666d',
        future_sha: '6e34798a3300894656f1f4e20c228f95eebe8027'
      }
      repo = GitHubRepo.new(
        change_args,
        IniFile.load(__dir__ + '/fixtures/github-config'),
        Octokit::Client.new(per_page: 1000),
        %w[LLNL tgmachina].to_set
      )
      expect(repo)
    end
  end
end
