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
      if @logger.debug?
        untrusted_collabs.each { |c| @logger.debug("#{c.name} is untrusted!") }
      end
      Codes::OK
    end

    def update
      if commit.protected_branch?(branch_name) && collabs_trusted?
        @logger.info('automatically syncing protected branch')
        return Codes::OK
      elsif vetted_by
        @logger.info(format('changes vetted by %<user>s',
                            user: vetted_by.commenter))
        return Codes::OK
      end
      @logger.info('changes denied')
      Codes::DENIED
    end

    def org_members
      @org_members ||= @client.org_members
    end

    def collaborators
      @collaborators ||= @client.collaborators(@repo.name)
    rescue ClientGenericError => e
      @logger.debug("failed getting collaborators: #{e}")
      @collaborators = []
    end

    def untrusted_collabs
      collaborators.reject { |name, _| org_members[name]&.trusted }
    end

    def collabs_trusted?
      return false if collaborators.empty?

      collaborators.all? { |name, _| org_members[name]&.trusted }
    end

    def branch_name
      hook_args[:ref_name].split('/')[-1]
    end

    def commit
      @commit ||= @client.commit(@repo.name, hook_args[:future_sha])
    end

    def comments
      @comments ||= @client.review_comments(@repo.name, hook_args[:future_sha],
                                            since: commit.date)
    rescue ClientGenericError => e
      @logger.debug("failed getting comments: #{e}")
      @comments = []
    end

    def signoff_bodies
      @signoff_bodies ||= @client.config[:signoff_bodies]&.map do |s|
        [s.downcase, true]
      end.to_h
    end

    def signoff?(body)
      signoff_bodies.key? body.downcase
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
