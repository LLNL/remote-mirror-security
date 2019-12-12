require 'ostruct'
require 'secure_mirror'
require 'github_repo'

RSpec.describe SecureMirror, '#init' do
  before(:each) do
    @repo_name = 'LLNL/Umpire'
    @hook_args = {
      ref_name: '/refs/head/backtrace',
      current_sha: '323c557025586778867c4574698bca8df760c2b7',
      future_sha: 'b48659a8c2b6555b7a6299fbddda0fef6adf7105'
    }
    @config_file = __dir__ + '/fixtures/config.json'
    @git_config_file = __dir__ + '/fixtures/github-config'
    @unsupported_git_config_file = __dir__ + '/fixtures/unsupported-config'
    @missing_file = '/tmp/nonexistent'
  end

  context 'creates a SecureMirror object' do
    it 'reads in various config properties' do
      allow(GitHubRepo).to receive(:new) { {} }
      sm = SecureMirror.new(@hook_args, @config_file, @git_config_file)
      expect(sm)
      expect(sm.name).to eq(@repo_name)
      expect(sm.misconfigured?).to be(false)
      expect(sm.mirror?).to be(true)
      expect(sm.new_repo?).to be(false)
    end

    it 'is marked as a new repo when failing to load the git config' do
      sm = SecureMirror.new(@hook_args, @config_file, @missing_file)
      expect(sm)
      expect(sm.new_repo?).to be(true)
    end

    it 'raises an error when unable to load the config file' do
      expect do
        SecureMirror.new(@hook_args, @missing_file, @git_config_file)
      end.to raise_error(Errno::ENOENT)
    end

    it 'has its repo set to nil when the remote is unsupported' do
      sm = SecureMirror.new(@hook_args, @config_file,
                            @unsupported_git_config_file)
      expect(sm)
      expect(sm.repo).to be(nil)
    end
  end
end
