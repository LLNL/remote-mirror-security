require 'inifile'
require 'date'

require 'mirror_security'
require 'repo'
require 'collaborator'
require 'commit'
require 'comment'

class MockRepo < Repo
  def initialize(change_args = nil, collaborators = nil, commit = nil,
                 comments = nil)
    @change_args = change_args || {
      ref_name: '/refs/head/foo',
      current_sha: '0000000000000000000000000000000000000000',
      future_sha: '6dcb09b5b57875f334f61aebed695e2e4193db5e'
    }
    @collaborators = collaborators || { foo: Collaborator.new('foo', true) }
    @commits = {}
    @commits[@change_args[:future_sha]] = commit || Commit.new(
      '6dcb09b5b57875f334f61aebed695e2e4193db5e',
      'feature', '2011-04-14T16:00:49Z', true
    )
    @comments = comments || [Comment.new('foo', 'LGTM', Date.today.to_s)]
  end
end

RSpec.describe MirrorSecurity, '#init' do
  context 'trusted collaborator vetting' do
    it 'vets changes' do
      future_sha = '6dcb09b5b57875f334f61aebed695e2e4193db5e'
      mock_repo = MockRepo.new
      expect(mock_repo.vetted_change?(future_sha))
    end

    it 'blocks unvetted changes' do
      future_sha = '6dcb09b5b57875f334f61aebed695e2e4193db5e'
      comments = [Comment.new('foo', 'does not LGTM', Date.today.to_s)]
      mock_repo = MockRepo.new(nil, nil, nil, comments)
      expect(mock_repo.vetted_change?(future_sha)).to be false
    end

    it 'does not vet for earlier comments' do
      future_sha = '6dcb09b5b57875f334f61aebed695e2e4193db5e'
      commit = Commit.new(
        '6dcb09b5b57875f334f61aebed695e2e4193db5e',
        'feature', Date.today.to_s, true
      )
      comments = [Comment.new('foo', 'LGTM', '2011-04-14T16:00:49Z')]
      mock_repo = MockRepo.new(nil, nil, commit, comments)
      expect(mock_repo.vetted_change?(future_sha)).to be false
    end

    it 'does not vet when there are no comments' do
      future_sha = '6dcb09b5b57875f334f61aebed695e2e4193db5e'
      mock_repo = MockRepo.new(nil, nil, nil, [])
      expect(mock_repo.vetted_change?(future_sha)).to be false
    end
  end

  context 'trusted changes' do
    it 'can determine when changes are trusted' do
      mock_repo = MockRepo.new
      expect(mock_repo.trusted_change?)
    end

    it 'trusts unvetted changes to protected branches' do
      mock_repo = MockRepo.new(nil, nil, nil, [])
      expect(mock_repo.trusted_change?)
    end

    it 'trusts vetted changes to unprotected branches' do
      commit = Commit.new(
        '6dcb09b5b57875f334f61aebed695e2e4193db5e',
        'feature', Date.today.to_s, false
      )
      mock_repo = MockRepo.new(nil, nil, commit, nil)
      expect(mock_repo.trusted_change?)
    end

    it 'does not trust unvetted changes from unprotected branches' do
      commit = Commit.new(
        '6dcb09b5b57875f334f61aebed695e2e4193db5e',
        'feature', Date.today.to_s, false
      )
      mock_repo = MockRepo.new(nil, nil, commit, [])
      expect(mock_repo.trusted_change?).to be false
    end
  end
end

