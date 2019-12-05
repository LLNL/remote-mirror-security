# describes basic security model for a mirror
module MirrorSecurity
  def vetted_change?(future_sha)
    commit_date = @commits[future_sha].date
    @comments.each do |comment|
      commenter = comment.commenter
      next unless @collaborators[commenter] &&
                  @collaborators[commenter].trusted
      next unless comment.body.casecmp(@signoff_body).zero?
      next unless comment.date > commit_date
      return true
    end
    false
  end

  def trusted_change?
    future_sha = @change_args[:future_sha]
    return false unless trusted_org? && @collaborators.each_value(&:trusted)
    return false unless protected_branch? || vetted_change?(future_sha)
    true
  end
end
