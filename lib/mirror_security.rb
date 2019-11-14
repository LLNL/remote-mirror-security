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
    return false unless in_org? && @collaborators.each_value(&:trusted)
    return true if @commits[future_sha].protections_enabled ||
                   vetted_change?(future_sha)
    false
  end
end
