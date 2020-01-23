# frozen_string_literal: true

# defines a collaborator on a repository
class Collaborator
  @name = ''
  @trusted = false

  attr_reader :name
  attr_reader :trusted

  def initialize(name, trusted)
    @name = name
    @trusted = trusted
  end
end
