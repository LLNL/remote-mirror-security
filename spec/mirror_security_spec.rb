require 'inifile'
require 'date'
require 'set'

require 'mirror_security'
require 'repo'
require 'collaborator'
require 'commit'
require 'comment'

class MockRepo < Repo
  def initialize(change_args = nil, collaborators = nil, current_commit = nil,
                 future_commit = nil, comments = nil, trusted_orgs = nil)
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
    @commits = {}
    @commits[@change_args[:current_sha]] = current_commit || Commit.new(
      '0000000000000000000000000000000000000000',
      'develop', '2011-01-14T16:00:49Z', true
    )
    @commits[@change_args[:future_sha]] = future_commit || Commit.new(
      '6dcb09b5b57875f334f61aebed695e2e4193db5e',
      'feature', '2011-04-14T16:00:49Z', false
    )
    @comments = comments || [Comment.new('foo', 'LGTM', Date.today.to_s)]
    @trusted_orgs = trusted_orgs || ['FooOrg'].to_set
  end
end

RSpec.describe MirrorSecurity, '#init' do
  context 'trusted collaborator' do
    it 'vets changes' do
      future_sha = '6dcb09b5b57875f334f61aebed695e2e4193db5e'
      mock_repo = MockRepo.new
      expect(mock_repo.vetted_change?(future_sha)).to be true
    end

    it 'blocks unvetted changes' do
      future_sha = '6dcb09b5b57875f334f61aebed695e2e4193db5e'
      comments = [Comment.new('foo', 'does not LGTM', Date.today.to_s)]
      mock_repo = MockRepo.new(nil, nil, nil, nil, comments, nil)
      expect(mock_repo.vetted_change?(future_sha)).to be false
    end

    it 'does not vet for earlier comments' do
      future_sha = '6dcb09b5b57875f334f61aebed695e2e4193db5e'
      commit = Commit.new(
        '6dcb09b5b57875f334f61aebed695e2e4193db5e',
        'feature', Date.today.to_s, true
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
        'feature', '2011-04-14T16:00:49Z', true
      )
      mock_repo = MockRepo.new(nil, nil, nil, future_commit, [], nil)
      expect(mock_repo.trusted_change?).to be true
    end

    it 'trusts vetted changes from unprotected branches' do
      future_commit = Commit.new(
        '6dcb09b5b57875f334f61aebed695e2e4193db5e',
        'feature', '2011-04-14T16:00:49Z', false
      )
      mock_repo = MockRepo.new(nil, nil, nil, future_commit, nil, nil)
      expect(mock_repo.trusted_change?).to be true
    end

    it 'does not trust unvetted changes from unprotected branches' do
      current_commit = Commit.new(
        '6dcb09b5b57875f334f61aebed695e2e4193db5e',
        'feature', '2011-04-14T16:00:49Z', false
      )
      future_commit = Commit.new(
        '6dcb09b5b57875f334f61aebed695e2e4193db5e',
        'feature', Date.today.to_s, false
      )
      mock_repo = MockRepo.new(nil, nil, current_commit, future_commit, [], nil)
      expect(mock_repo.trusted_change?).to be false
    end
  end
end

