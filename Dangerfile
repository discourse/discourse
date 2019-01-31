if github.pr_json && (github.pr_json["additions"] || 0) > 250 || (github.pr_json["deletions"] || 0) > 250
  warn("This pull request is big! We prefer smaller PRs whenever possible, as they are easier to review. Can this be split into a few smaller PRs?")
end

prettier_offenses = `yarn --silent prettier --list-different "app/assets/stylesheets/**/*.scss" "app/assets/javascripts/**/*.es6" "test/javascripts/**/*.es6"`.split("\n")

unless prettier_offenses.empty?
  fail(%{
This PR doesn't match our required code formatting standards, as enforced by prettier.io. <a href='https://meta.discourse.org/t/prettier-code-formatting-tool/93212'>Here's how to set up prettier in your code editor.</a>\n
#{prettier_offenses.map { |o| github.html_link(o) }.join("\n")}
  })
end

locales_changes = git.modified_files.grep(/config\/locales/)
has_non_en_locales_changes = locales_changes.grep_v(/config\/locales\/(client|server)\.en\.yml/).any?

if locales_changes.any? && has_non_en_locales_changes
  fail("Please submit your non-English translation updates via [Transifex](https://www.transifex.com/discourse/discourse-org/). You can read more on how to contribute translations [here](https://meta.discourse.org/t/contribute-a-translation-to-discourse/14882).")
end

files = (git.added_files + git.modified_files)
  .select { |path| !path.start_with?("plugins/") }
  .select { |path| path.end_with?("es6") || path.end_with?("rb") }

super_offenses = []

files.each do |path|
  diff = git.diff_for_file(path)

  next if !diff

  diff.patch.lines.grep(/^\+\s\s/).each do |added_line|
    super_offenses << path if added_line['this._super()']
  end
end

if !super_offenses.empty?
  warn(%{
When possible use `this._super(...arguments)` instead of `this._super()`\n
#{super_offenses.uniq.map { |o| github.html_link(o) }.join("\n")}
  })
end
