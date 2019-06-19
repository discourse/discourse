task 'turbo:spec' => :test do |t|
  require './lib/turbo_tests'

  TurboTests.run([{name: 'progress', outputs: ['-']}], ['spec'])
end
