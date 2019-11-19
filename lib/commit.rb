require 'date'
require 'time'

# defines a git commit
class Commit
  @sha = ''
  @branch_name = ''
  @date = nil
  @protections_enabled = false

  attr_reader :sha
  attr_reader :branch_name
  attr_reader :date
  attr_reader :protections_enabled

  def initialize(sha, branch_name, date, protections_enabled)
    @sha = sha
    @branch_name = branch_name
    if date.is_a?(Time)
      @date = date
    elsif date.is_a?(Date)
      @date = date.to_time
    elsif date.is_a?(String)
      @date = Time.parse(date)
    end
    @protections_enabled = protections_enabled
  end
end
