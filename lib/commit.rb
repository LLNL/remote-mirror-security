# frozen_string_literal: true

require 'date'
require 'time'

# defines a git commit
class Commit
  @sha = ''
  @date = nil

  attr_reader :sha
  attr_reader :date

  def initialize(sha, date)
    @sha = sha
    if date.is_a?(Time)
      @date = date
    elsif date.is_a?(Date)
      @date = date.to_time
    elsif date.is_a?(String)
      @date = Time.parse(date)
    end
  end
end
