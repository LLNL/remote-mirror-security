# frozen_string_literal: true

require 'time'
require 'commit'

RSpec.describe Commit, '#init' do
  context 'creates a basic commit object' do
    it 'houses only basic, necessary info' do
      commit = Commit.new('6dcb09b5b57875f334f61aebed695e2e4193db5e',
                          '2011-04-14T16:00:49Z')
      expect(commit.sha).to eq '6dcb09b5b57875f334f61aebed695e2e4193db5e'
      expect(commit.date).to be < Time.now
    end
  end
end
