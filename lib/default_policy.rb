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

require 'helpers'
require 'policy'
require 'mirror_client'

module SecureMirror
  # defines a policy for mirror security to enforce
  class DefaultPolicy < Policy
    def pre_receive
      # make calls here so that they are cached before update
      org_members
      collaborators
      Codes::OK
    end

    def update
      return Codes::OK if protected_branch? && collabs_trusted?
      return Codes::OK if vetted_change?

      Codes::DENIED
    end

    def org_members
      @client.org_members(@config[:trusted_org])
    end

    def collaborators
      @client.collaborators(@repo.name)
    end

    def collabs_trusted?
      collaborators.all? { |name, _| org_members[name].trusted }
    end

    def branches
      @client.branches(@repo.name, hook_args)
    end

    def branch_name
      hook_args[:ref_name].split('/')[-1]
    end

    def protected_branch?
      branches.any? { |b| b[:name] == branch_name && b[:protection] }
    end

    def commit
      @client.commit(@repo.name, hook_args[:future_sha])
    end

    def comments
      @client.review_comments(@repo.name, hook_args[:future_sha],
                              since: commit.date)
    end

    def signoff_bodies
      @client.config[:signoff_bodies]&.map { |s| [s.downcase, true] }.to_h
    end

    def signoff?(body)
      signoff_bodies.include? body.downcase
    end

    def vetted_change?
      return false unless commit

      comments.each do |comment|
        commenter = comment.commenter
        next unless org_members[commenter]&.trusted

        next unless signoff? comment.body

        next unless comment.date > commit.date

        @logger.info(format('Changes for %<sha>s vetted by %<user>s',
                            sha: future_sha, user: commenter))
        return true
      end
      false
    end
  end
end

