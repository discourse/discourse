# frozen_string_literal: true

task 'turbo:spec' => :test do |t|
  require './lib/turbo_tests'

  TurboTests::Runner.run(
    formatters: [{ name: 'progress', outputs: ['-'] }],
    files: ['spec']
  )
end
