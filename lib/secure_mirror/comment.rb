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
  # defines a comment
  class Comment
    attr_reader :commenter, :body, :date

    def initialize(commenter = '', body = '', date = nil)
      @commenter = commenter
      @body = body
      @date = date.is_a?(String) ? Time.parse(date) : date&.to_time
    end

    def as_json
      { klass: self.class.name, commenter: @commenter, body: @body, date: @date }
    end

    def to_json(*options)
      as_json.to_json(*options)
    end

    def self.from_json(json_obj)
      new(json_obj[:commenter], json_obj[:body], json_obj[:date])
    end
  end
end
