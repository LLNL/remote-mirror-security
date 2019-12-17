# Secure Mirror

Framework for building git hooks that apply logic to secure changes from
remote mirrors.

# Architecture

This project relies on the `update.d` git hook to evaulate inbound repository
changes.

The `update.d` hook runs for every `ref` being mirrored (excluding refs
pointing to forks). The hook receives 3 arguments:

* The `ref` name `refs/head/foo`
* The current `sha` the local repository knows of
* The future `sha` that the local repository will be updated to (the latest
`sha` of the remote mirror)

Using this data, the secure mirror incorporates a small set of abstractions:

* A repository class that aggregates:
  * Branch data
  * Commit data (specifically for the `sha`s in the `update.d` args)
  * Organization members
  * Repository collaborators
  * Pull Request (Merge Request) comments
* A module mixin that uses the simplified repo data to evaluate trust

In general, this information is used to say:

* The collaborators (with write to protected branches) are trusted and
therefore changes to protected branches are trusted.
* Organization members who are are trusted can vouch for a set of changes.

# Package as a gem

```bash
./script/package
```

# Basic use

```ruby
require 'secure_mirror'

exit evaluate_changes(config_file: '/absolute/path/to/config.json')
```
