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
      if protected_branch? && collabs_trusted?
        @logger.info('automatically syncing protected branches')
        return Codes::OK
      elsif vetted_by
        @logger.info(format('Changes for %<sha>s vetted by %<user>s',
                            sha: hook_args[:future_sha],
                            user: vetted_by.commenter))
        return Codes::OK
      end
      Codes::DENIED
    end

    def org_members
      @org_members ||= @client.org_members(@config[:trusted_org])
    end

    def collaborators
      @collaborators ||= @client.collaborators(@repo.name)
    end

    def collabs_trusted?
      collaborators.all? { |name, _| org_members[name].trusted }
    end

    def branches
      @branches ||= @client.branches(@repo.name, hook_args)
    end

    def branch_name
      hook_args[:ref_name].split('/')[-1]
    end

    def protected_branch?
      branches.any? { |b| b[:name] == branch_name && b[:protection] }
    end

    def commit
      @commit ||= @client.commit(@repo.name, hook_args[:future_sha])
    end

    def comments
      @comments ||= @client.review_comments(@repo.name, hook_args[:future_sha],
                                            since: commit.date)
    end

    def signoff_bodies
      @signoff_bodies ||= @client.config[:signoff_bodies]&.map do |s|
        [s.downcase, true]
      end.to_h
    end

    def signoff?(body)
      signoff_bodies.include? body.downcase
    end

    def vetted_by
      return nil unless commit

      comments
        .select { |c| org_members[c.commenter]&.trusted }
        .select { |c| signoff?(c.body) && c.date > commit.date }
        .first
    end
  end
end
