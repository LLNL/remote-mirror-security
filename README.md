# Secure Mirror

Framework for building git hooks that apply logic to secure changes from
remote mirrors.

# Architecture

This project primarily relies on the `update.d` git hook to evaulate inbound
repository changes.

The `update.d` hook runs for every `ref` being mirrored (excluding refs
pointing to forks). The hook receives 3 arguments:

* The `ref` name `refs/head/foo`
* The current `sha` the local repository knows of
* The future `sha` that the local repository will be updated to (the latest
`sha` of the remote mirror)

Using this data, the secure mirror incorporates a small set of abstractions:

* A generic remote client that aggregates:
  * Branch data
  * Commit data (specifically for the `sha`s in the `update.d` args)
  * Organization members
  * Repository collaborators
  * Pull Request (Merge Request) comments
* A generic policy class that uses the client data to evaluate a remote's
posture

In general, this information is used to say:

* The collaborators (with write to protected branches) are trusted and
therefore changes to protected branches are trusted.
* Organization members who are are trusted can vouch for a set of changes.

Since the `update.d` hook is run for *every* inbound change, this project now
also enables caching to disk. Redundant calls can be made initially during the
`pre-receive` hook phase and their responses re-read during `update`. Finally,
`post-receive` can be used to clear out the cache (otherwise the data will
expire after a configurable time limit).

# Package as a gem

```bash
./script/package
```

# Basic use
The `evaluate_changes` returns an integer error code that determines whether or
not to allow the changes. Providing the current phase (`pre-receive`, `update`,
or `post-receive`) will trigger the appropriate policy actions for that phase.

Further, a custom policy subclass can redefine how each hook phase evaluates
changes or caches data.

```ruby
# in the update.d hook
require 'secure_mirror'

exit SecureMirror.evaluate_changes(
  'update',
  'gitlab',
  config_file: '/path/to/config.json'
)
```

Starting in version `0.3.0`, this gem includes a script `secure-mirror` which can automatically setup or teardown the necessary hooks.

```bash
# create the hooks
secure-mirror --enable

# the hook prefix and config file locations are configurable
secure-mirror --enable --gitlab-shell-prefix /path/to/git/hook/root --config /path/to/mirror/config.json

# to remove all installed hooks
secure-mirror --disable
```

# Release

This code is released under the MIT License. For more details see the LICENSE File.

SPDX-License-Identifier: MIT

LLNL-CODE-801838
