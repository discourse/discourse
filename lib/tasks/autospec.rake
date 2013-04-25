# I like guard, don't get me wrong, but it is just not working right
# architectually it can not do what I want it to do, this is how I want
# it to behave

desc "Run all specs automatically as needed"
task "autospec" => :environment do
  require 'autospec/runner'
  Autospec::Runner.run
end
