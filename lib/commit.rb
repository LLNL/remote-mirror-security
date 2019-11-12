require 'date'

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
    @date = Date.parse(date)
    @protections_enabled = protections_enabled
  end
end
