# describes basic security model for a mirror
module MirrorSecurity
  def vetted_change?(future_sha)
    commit_date = @commits[future_sha].date
    @comments.each do |comment|
      commenter = comment.commenter
      next unless @org_members[commenter] &&
                  @org_members[commenter].trusted
      next unless comment.body.casecmp(@signoff_body).zero?
      next unless comment.date > commit_date
      return true
    end
    false
  end

  def trusted_change?
    future_sha = @hook_args[:future_sha]
    return true if protected_branch? && !@collaborators.empty? &&
                   @collaborators.all? { |_, v| v.trusted }
    return true if vetted_change?(future_sha)
    false
  end
end
