task 'interleaved:spec' => :test do |t|
  require './lib/interleaved_tests'

  InterleavedTests.run([{name: 'progress', outputs: ['-']}], ['spec'])
end
