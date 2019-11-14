# describes basic security model for a mirror
module MirrorSecurity
  def vetted_change?(future_sha)
    signoff_body = @signoff_body
    commit_date = @commits[future_sha].date
    @comments.each do |comment|
      next unless comment.body.casecmp(signoff_body)
      next unless comment.date > commit_date
      return true
    end
    false
  end

  def trusted_change?
    current_sha = @change_args[:current_sha]
    future_sha = @change_args[:future_sha]
    return false unless in_org? && @collaborators.all?(:trusted)
    return true if @commits[current_sha].protections_enabled ||
                   vetted_change?(future_sha)
    false
  end
end
