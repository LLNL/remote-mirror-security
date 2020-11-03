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

module SecureMirror
  # defines a git commit
  class Commit
    attr_reader :sha, :date, :branches

    def initialize(sha = '', date = nil, branches = [])
      @sha = sha
      @date = date.is_a?(String) ? Time.parse(date) : date&.to_time
      @branches = branches
    end

    def as_json
      { klass: self.class.name, sha: @sha, date: @date, branches: branches }
    end

    def to_json(*options)
      as_json.to_json(*options)
    end

    def self.from_json(json_obj)
      new(json_obj[:sha], json_obj[:date], json_obj[:branches])
    end

    def protected_branch?(branch_name)
      @branches.any? do |branch|
        branch[:name] == branch_name && branch[:protection]
      end
    end
  end
end
