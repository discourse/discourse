require 'json'
require 'shellwords'

if git.lines_of_code > 500
  warn("This PR seems big, we prefer smaller PR. Please be sure this is needed and can't be split in smaller PRs.")
end

to_lint = git.modified_files + git.added_files
files_to_lint = Shellwords.join(to_lint)
rubocop_output = `bundle exec rubocop -f json --parallel #{files_to_lint}`
if !rubocop_output.empty?
  offenses = JSON.parse(rubocop_output)['files']
    .select { |f| f['offenses'].any? }

  def format_offense(offense)
    output = "file: #{offense['path']}\n"
    offense['offenses'].each do |o|
      output << "#{o['message']} (line:#{o['location']['start_line']}, col:#{o['location']['start_column']})\n"
    end
    output << "\n"
  end

  if !offenses.empty?
    fail(%{
This PR has multiple rubocop offenses. We recommend configuring prettier linting in your editor:\n
#{offenses.map { |o| format_offense(o) }.join('\n') }
    })
  end
end

prettier_offenses = `prettier --list-different "app/assets/stylesheets/**/*.scss" "app/assets/javascripts/**/*.es6" "test/javascripts/**/*.es6" "plugins/**/*.scss" "plugins/**/*.es6"`.split('\n')
if !prettier_offenses.empty?
  fail(%{
This PR has multiple prettier offenses (prettier.io). We recommend configuring prettier linting in your editor:\n
#{prettier_offenses.join("\n")}
  })
end
