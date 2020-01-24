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
