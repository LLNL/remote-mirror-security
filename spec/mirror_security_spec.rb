require 'inifile'
require 'time'
require 'set'

require 'mirror_security'
require 'repo'
require 'collaborator'
require 'commit'
require 'comment'

class MockRepo < Repo
  def protected_branch?
    @branch_protected
  end

  def initialize(change_args = nil, collaborators = nil, current_commit = nil,
                 future_commit = nil, comments = nil, trusted_org = nil,
                 branch_protected = false)
    @url = 'https://github.com/FooOrg/bar.git'
    @name = 'FooOrg/bar'
    @signoff_body = 'lgtm'
    @change_args = change_args || {
      ref_name: '/refs/head/foo',
      current_sha: '0000000000000000000000000000000000000000',
      future_sha: '6dcb09b5b57875f334f61aebed695e2e4193db5e'
    }
    @collaborators = collaborators || {}
    if @collaborators.empty?
      @collaborators['foo'] = Collaborator.new('foo', true)
    end
    @org_members = @collaborators
    @commits = {}
    @commits[@change_args[:current_sha]] = current_commit || Commit.new(
      '0000000000000000000000000000000000000000',
      '2011-01-14T16:00:49Z'
    )
    @commits[@change_args[:future_sha]] = future_commit || Commit.new(
      '6dcb09b5b57875f334f61aebed695e2e4193db5e',
      '2011-04-14T16:00:49Z'
    )
    @comments = comments || [Comment.new('foo', 'LGTM', Time.now.to_s)]
    @trusted_org = trusted_org || 'FooOrg'
    @branch_protected = branch_protected
  end
end

RSpec.describe MirrorSecurity, '#init' do
  context 'trusted collaborator' do
    it 'vets changes' do
      future_sha = '6dcb09b5b57875f334f61aebed695e2e4193db5e'
      mock_repo = MockRepo.new(nil, nil, nil, nil, nil, nil, true)
      expect(mock_repo.vetted_change?(future_sha)).to be true
    end

    it 'blocks unvetted changes' do
      future_sha = '6dcb09b5b57875f334f61aebed695e2e4193db5e'
      comments = [Comment.new('foo', 'does not LGTM', Time.now.to_s)]
      mock_repo = MockRepo.new(nil, nil, nil, nil, comments, nil)
      expect(mock_repo.vetted_change?(future_sha)).to be false
    end

    it 'does not vet for earlier comments' do
      future_sha = '6dcb09b5b57875f334f61aebed695e2e4193db5e'
      commit = Commit.new(
        '6dcb09b5b57875f334f61aebed695e2e4193db5e',
        Time.now.to_s
      )
      comments = [Comment.new('foo', 'LGTM', '2011-04-14T16:00:49Z')]
      mock_repo = MockRepo.new(nil, nil, nil, commit, comments, nil)
      expect(mock_repo.vetted_change?(future_sha)).to be false
    end

    it 'does not vet when there are no comments' do
      future_sha = '6dcb09b5b57875f334f61aebed695e2e4193db5e'
      mock_repo = MockRepo.new(nil, nil, nil, nil, [], nil)
      expect(mock_repo.vetted_change?(future_sha)).to be false
    end
  end

  context 'trusted changes' do
    it 'can determine when changes are trusted' do
      mock_repo = MockRepo.new
      expect(mock_repo.trusted_change?).to be true
    end

    it 'trusts unvetted changes in protected branches' do
      future_commit = Commit.new(
        '6dcb09b5b57875f334f61aebed695e2e4193db5e',
        '2011-04-14T16:00:49Z'
      )
      mock_repo = MockRepo.new(nil, nil, nil, future_commit, [], nil, true)
      expect(mock_repo.trusted_change?).to be true
    end

    it 'trusts vetted changes from unprotected branches' do
      future_commit = Commit.new(
        '6dcb09b5b57875f334f61aebed695e2e4193db5e',
        '2011-04-14T16:00:49Z'
      )
      mock_repo = MockRepo.new(nil, nil, nil, future_commit, nil, nil)
      expect(mock_repo.trusted_change?).to be true
    end

    it 'does not trust unvetted changes from unprotected branches' do
      current_commit = Commit.new(
        '6dcb09b5b57875f334f61aebed695e2e4193db5e',
        '2011-04-14T16:00:49Z'
      )
      future_commit = Commit.new(
        '6dcb09b5b57875f334f61aebed695e2e4193db5e',
        Time.now.to_s
      )
      mock_repo = MockRepo.new(nil, nil, current_commit, future_commit, [], nil)
      expect(mock_repo.trusted_change?).to be false
    end
  end
end

