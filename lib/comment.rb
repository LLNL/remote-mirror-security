require 'date'

# defines a comment
class Comment
  @commenter = ''
  @body = ''
  @date = nil

  attr_reader :commenter
  attr_reader :body
  attr_reader :date

  def initialize(commenter, body, date)
    @commenter = commenter
    @body = body
    @date = Date.parse(date)
  end
end
