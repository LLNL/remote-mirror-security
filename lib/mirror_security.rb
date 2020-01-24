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

# describes basic security model for a mirror
module MirrorSecurity
  def vetted_change?(future_sha)
    return false unless @commits[future_sha]

    commit_date = @commits[future_sha].date
    @comments.each do |comment|
      commenter = comment.commenter
      @logger.debug('Evaluating comment from %s' % commenter)
      next unless @org_members[commenter]&.trusted

      @logger.debug('User is trusted')
      next unless comment.body.casecmp(@signoff_body).zero?

      @logger.debug('Signoff matches')
      next unless comment.date > commit_date

      @logger.info('Changes in commit %s vetted by %s' %
                   [future_sha, commenter])
      return true
    end
    false
  end

  def trusted_change?
    return true if protected_branch? && collabs_trusted?
    return true if vetted_change?(@hook_args[:future_sha])

    false
  end
end
