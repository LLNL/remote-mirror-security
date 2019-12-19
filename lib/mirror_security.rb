# describes basic security model for a mirror
module MirrorSecurity
  def vetted_change?(future_sha)
    commit_date = @commits[future_sha].date
    @comments.each do |comment|
      commenter = comment.commenter
      @logger.debug('Evaluating comment from %s' % commenter)
      next unless @org_members[commenter] &&
                  @org_members[commenter].trusted
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
    future_sha = @hook_args[:future_sha]
    return true if protected_branch? && collabs_trusted?
    return true if vetted_change?(future_sha)
    false
  end
end
