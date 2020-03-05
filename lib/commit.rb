# frozen_string_literal: true

###############################################################################
# Copyright (c) 2020, Lawrence Livermore National Security, LLC
# Produced at the Lawrence Livermore National Laboratory
# Written by Thomas Mendoza mendoza33@llnl.gov
# LLNL-CODE-801838
# All rights reserved
#
# This file is part of Remote Mirror Security:
# https://github.com/LLNL/remote-mirror-security
#
# SPDX-License-Identifier: MIT
###############################################################################

require 'date'
require 'time'

# defines a git commit
class Commit
  @sha = ''
  @date = nil
  @branches = []

  attr_reader :sha
  attr_reader :date
  attr_reader :branches

  def as_json(*)
    { klass: self.class.name, sha: @sha, date: @date, branches: branches }
  end

  def to_json(*options)
    as_json(*options).to_json(*options)
  end

  def self.from_json(json_obj)
    new(json_obj[:sha], json_obj[:date], branches: json_obj[:branches])
  end

  def protected_branch?(branch_name)
    @branches.any? do |branch|
      branch[:name] == branch_name && branch[:protection]
    end
  end

  def initialize(sha, date, branches: nil)
    @sha = sha
    if date.is_a?(Time)
      @date = date
    elsif date.is_a?(Date)
      @date = date.to_time
    elsif date.is_a?(String)
      @date = Time.parse(date)
    end
    @branches = branches
  end
end
