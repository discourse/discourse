# frozen_string_literal: true

require "tmpdir"

RSpec.describe Migrations::Conversion::ChunkQueue do
  it "hands out every index once, in order, then nil" do
    queue = described_class.filled(3)
    expect([queue.claim, queue.claim, queue.claim]).to eq([0, 1, 2])
    expect(queue.claim).to be_nil
    expect(queue.claim).to be_nil # stays empty
  end

  it "is empty from the start for a count of zero" do
    expect(described_class.filled(0).claim).to be_nil
  end

  it "raises rather than deadlock when the bag can't fit in the pipe buffer" do
    expect { described_class.filled(1_000_000) }.to raise_error(ArgumentError, /pipe buffer/)
  end

  it "splits the indices across forked workers with no gaps or duplicates" do
    count = 500
    workers = 6
    queue = described_class.filled(count)

    Dir.mktmpdir do |dir|
      paths = Array.new(workers) { |w| File.join(dir, "claims-#{w}") }
      pids =
        workers.times.map do |w|
          fork do
            claimed = []
            while (index = queue.claim)
              claimed << index
            end
            File.write(paths[w], claimed.join(" "))
            Process.exit!(0)
          end
        end
      queue.close
      pids.each { |pid| Process.waitpid(pid) }

      collected = paths.flat_map { |path| File.read(path).split.map(&:to_i) }
      expect(collected.sort).to eq((0...count).to_a) # each index claimed exactly once
    end
  end
end
