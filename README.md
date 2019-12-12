# Secure Mirror

Framework for building git hooks that apply logic to securing changes from
remote mirrors.

# Package as a gem

```bash
./script/package
```

# Basic use

```ruby
require 'secure_mirror'

exit evaluate_changes(config_file: '/absolute/path/to/config.json')
```
