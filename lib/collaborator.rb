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
  # defines a collaborator on a repository
  class Collaborator
    @name = ''
    @trusted = false

    attr_reader :name
    attr_reader :trusted

    def as_json(*)
      { klass: self.class.name, name: @name, trusted: @trusted }
    end

    def to_json(*options)
      as_json(*options).to_json(*options)
    end

    def self.from_json(json_obj)
      new(json_obj[:name], json_obj[:trusted])
    end

    def initialize(name, trusted)
      @name = name
      @trusted = trusted
    end
  end
end
