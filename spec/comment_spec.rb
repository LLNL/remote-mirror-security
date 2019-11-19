require 'time'
require 'comment'

RSpec.describe Comment, '#init' do
  context 'creates a basic comment object' do
    it 'houses only basic, necessary info' do
      comment = Comment.new('me', 'hello', '2011-04-14T16:00:49Z')
      expect(comment.body).to eq 'hello'
      expect(comment.date).to be < Time.now
    end
  end
end
