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
  class MirrorClient
    attr_accessor :client, :alt_clients

    def initialize
      @client = nil
      @alt_clients = nil
    end

    def org_members(org: '', client_name: '', expires: nil)
      raise NotImplementedError
    end

    def collaborators(repo, client_name: '', expires: nil)
      raise NotImplementedError
    end

    def commit(repo, sha, client_name: '', expires: nil)
      raise NotImplementedError
    end

    def branches(repo, sha, client_name: '')
      raise NotImplementedError
    end

    def review_comments(repo, sha, client_name: '', expires: nil)
      raise NotImplementedError
    end
  end
end
