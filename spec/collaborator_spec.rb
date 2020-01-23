# frozen_string_literal: true

require 'collaborator'

RSpec.describe Collaborator, '#init' do
  context 'creates a basic collaborator object' do
    it 'initializes with a name and whether or not theyre trusted' do
      collab = Collaborator.new('foo', true)
      expect(collab.name).to be_truthy
      expect(collab.trusted)
    end
  end
end
