# frozen_string_literal: true

task "turbo:spec" => :test do
  sh "bin/turbo_rspec"
end
