require 'json'

if git.lines_of_code > 500
  warn("This PR seems big, we prefer smaller PR. Please be sure this is needed and can’t be split in smaller commits.")
end

rubocop_output = `bundle exec rubocop --parallel`
if !rubocop_output.empty?
  offenses = JSON.parse(rubocop_output)['files']
    .select { |f| f['offenses'].any? }

  fail(%{
    This PR has multiple rubocop offenses:

    #{offenses.join("\n")}
  })
end

prettier_output = `prettier --list-different "app/assets/stylesheets/**/*.scss" "app/assets/javascripts/**/*.es6" "test/javascripts/**/*.es6" "plugins/**/*.scss" "plugins/**/*.es6"`
if !prettier_output.empty?
  offenses = JSON.parse(prettier_output)['files']
    .select { |f| f['offenses'].any? }

  fail(%{
    This PR has multiple prettier offenses:

    #{offenses.join("\n")}
  })
end
