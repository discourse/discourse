# spring speeds up your dev environment, similar to zeus but build in Ruby
#
# gem install spring
#
# spring binstub rails
# spring binstub rake
# spring binstub rspec
Spring.after_fork do
  $redis.client.reconnect
  MessageBus.reliable_pub_sub.pub_redis.client.reconnect
  Rails.cache.reconnect
end
Spring::Commands::Rake.environment_matchers["spec"] = "test"
