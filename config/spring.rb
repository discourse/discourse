# frozen_string_literal: true

# spring speeds up your dev environment, similar to zeus but build in Ruby
#
# gem install spring
#
# spring binstub rails
# spring binstub rake
# spring binstub rspec
Spring.after_fork do
  Discourse.after_fork
end
Spring::Commands::Rake.environment_matchers["spec"] = "test"
