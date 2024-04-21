# frozen_string_literal: true

RSpec.describe DiscoursePoll::Irv do
  it "correctly finds the winner with a simple majority" do
    votes = [%w[Alice Bob], %w[Bob Alice], %w[Alice Bob], %w[Bob Alice], %w[Alice Bob]]
    expect(described_class.irv_outcome(votes)[:winning_candidate]).to eq("Alice")
  end

  it "correctly finds the winner after one elimination" do
    votes = [
      %w[Alice Bob Charlie],
      %w[Bob Charlie Alice],
      %w[Charlie Alice Bob],
      %w[Charlie Alice Bob],
      %w[Bob Charlie Alice],
    ]
    expect(described_class.irv_outcome(votes)[:winning_candidate]).to eq("Bob")
  end

  it "handles a tie" do
    votes = [
      %w[Alice Bob Charlie Dave],
      %w[Bob Charlie Dave Alice],
      %w[Charlie Dave Alice Bob],
      %w[Dave Alice Bob Charlie],
      %w[Bob Dave Charlie Alice],
      %w[Dave Charlie Bob Alice],
    ]
    expect(described_class.irv_outcome(votes)[:tied_candidates]).to eq(%w[Bob Dave])
  end

  it "handles multiple rounds of elimination and tracks round activity" do
    votes = [
      %w[Alice Bob Charlie Dave],
      %w[Bob Charlie Dave Alice],
      %w[Charlie Dave Alice Bob],
      %w[Dave Alice Bob Charlie],
      %w[Bob Dave Charlie Alice],
      %w[Dave Charlie Bob Alice],
    ]
    expect(described_class.irv_outcome(votes)[:round_activity].length).to eq(2)
  end

  it "handles  the winner with a simple majority" do
    votes = [%w[David Alice], %w[Bob David]]
    expect(described_class.irv_outcome(votes)[:tied_candidates]).to eq(%w[David Bob])
  end
end
