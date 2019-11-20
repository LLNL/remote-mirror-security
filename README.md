# Secure Mirror

Framework for building git hooks that apply logic to securing changes from
remote mirrors.

# Package as a gem

```bash
./script/package
```

# Basic use

```ruby
require 'set'
require 'inifile'
require 'secure-mirror'

ACCESS_TOKEN = 'TOKEN_GOES_HERE'.freeze

github_client = Octokit::Client.new(per_page: 1000, access_token: ACCESS_TOKEN)

# the environment variables are provided by the git update hook
change_args = {
  ref_name: ENV[0],
  current_sha: ENV[1],
  future_sha: ENV[2],
}

# `pwd` for the hook will be the git directory itself
begin
  git_config IniFile.load(__dir__ + '/config'),
rescue Errno::ENOENT
  exit 1
end

repo = GitHubRepo.new(change_args, git_config, github_client, %w[LLNL].to_set,
                      'lgtm')

# failed init, we can make no determinations about this repo
exit 1 if !repo

# if the repo is not a mirror, this is a normal git operation: allow it
exit 0 if !repo.is_mirror

# allow the mirror changes only if they are trusted
exit 0 if repo.trusted_change?

# deny if we made it this far
exit 1
```
