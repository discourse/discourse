# frozen_string_literal: true

RSpec.describe Migrations::Importer::Uploads::Batcher do
  subject(:batcher) { described_class.new(queue, batch_size) }

  let(:queue) { Queue.new }
  let(:batch_size) { 3 }

  def drained
    [].tap { |batches| batches << queue.pop until queue.empty? }
  end

  it "hands off a full batch and starts a fresh one" do
    6.times { |i| batcher.push(i) }

    expect(drained).to eq([[0, 1, 2], [3, 4, 5]])
  end

  it "does not hand off a partial batch until it is flushed" do
    batcher.push(:a)
    batcher.push(:b)

    expect(queue).to be_empty

    batcher.flush
    expect(drained).to eq([%i[a b]])
  end

  it "flushes nothing when the buffer is empty" do
    batcher.flush

    expect(queue).to be_empty
  end

  it "keeps each handed-off batch capped at the batch size" do
    10.times { |i| batcher.push(i) }
    batcher.flush

    expect(drained.map(&:size)).to eq([3, 3, 3, 1])
  end
end
