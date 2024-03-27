## Gemfiles for migrations-tooling

This directory contains Gemfiles for the migration related tools.

Those tools use `bundler/inline`, so this isn't strictly needed. However, we use GitHub's Dependabot to keep the dependencies up-to-date, and it requires a Gemfile to work.

Please add an entry in the `.github/workflows/dependabot.yml` file when you add a new Gemfile to enable Dependabot for the Gemfile.

#### Example
```yaml
  - package-ecosystem: "bundler"
    directory: "migrations/config/gemfiles/convert"
    schedule:
      interval: "weekly"
      day: "wednesday"
      time: "10:00"
      timezone: "Europe/Vienna"
    versioning-strategy: "increase"
```
