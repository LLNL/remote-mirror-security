require 'inifile'
require 'date'
require 'repo'

RSpec.describe Repo, '#init' do
  context 'creates a basic repo object' do
    it 'initializes with a git config ini file' do
      change_args = {
        ref_name: '/refs/head/foo',
        current_sha: '0000000000000000000000000000000000000000',
        future_sha: '6dcb09b5b57875f334f61aebed695e2e4193db5e'
      }
      repo = Repo.new(change_args, IniFile.load(__dir__ + '/fixtures/config'))
      expect(repo)
    end
  end
end
