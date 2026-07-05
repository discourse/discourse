# frozen_string_literal: true

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

  # Claiming across real forks — that several workers split the indices with no
  # gaps or duplicates — is covered end to end by the scheduler integration spec
  # ("splits a partitioned step across forks"): a double-claim or a missed chunk
  # would leave the merged table with duplicate or missing rows.
end
