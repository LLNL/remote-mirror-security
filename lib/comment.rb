require 'date'
require 'time'

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
    if date.is_a?(Time)
      @date = date
    elsif date.is_a?(Date)
      @date = date.to_time
    elsif date.is_a?(String)
      @date = Time.parse(date)
    end
  end
end
