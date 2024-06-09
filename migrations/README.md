# Migrations Tooling

## Command line interface

```bash
./bin/cli help
```

## Converters

Public converters are stored in `lib/converters/`.
If you need to run a private converter, put its code into a subdirectory of `private/converters/`

## Development

### Installing Gems

```bash
bundle config set --local with migrations
bundle install
```

### Running tests

You need to execute `rspec` in the root of the project.

```bash
bin/rspec --default-path migrations/spec
```
