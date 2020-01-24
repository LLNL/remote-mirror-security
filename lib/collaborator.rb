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
