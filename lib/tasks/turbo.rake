task 'turbo:spec' => :test do |t|
  require './lib/turbo_tests'

  TurboTests::Runner.run([{name: 'progress', outputs: ['-']}], ['spec'])
end
