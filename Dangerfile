if git.lines_of_code > 500
  warn("This PR seems big, we prefer smaller PR. Please be sure this is needed and can't be split in smaller PRs.")
end

prettier_offenses = `prettier --list-different "app/assets/stylesheets/**/*.scss" "app/assets/javascripts/**/*.es6" "test/javascripts/**/*.es6"`.split('\n')
if !prettier_offenses.empty?
  fail(%{
This PR has multiple prettier offenses (prettier.io). We recommend configuring prettier linting in your editor:\n
#{prettier_offenses.join("\n")}
  })
end
