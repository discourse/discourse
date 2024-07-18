# frozen_string_literal: true

RSpec.describe DiscoursePoll::RankedChoice do
  let(:options_1) { [{ id: "Alice", html: "Alice" }, { id: "Bob", html: "Bob" }] }
  let(:options_2) do
    [{ id: "Alice", html: "Alice" }, { id: "Bob", html: "Bob" }, { id: "Charlie", html: "Charlie" }]
  end
  let(:options_3) do
    [
      { id: "Alice", html: "Alice" },
      { id: "Bob", html: "Bob" },
      { id: "Charlie", html: "Charlie" },
      { id: "Dave", html: "Dave" },
    ]
  end

  it "correctly finds the winner with a simple majority" do
    votes = [%w[Alice Bob], %w[Bob Alice], %w[Alice Bob], %w[Bob Alice], %w[Alice Bob]]
    expect(described_class.run(votes, options_1)[:winning_candidate]).to eq(
      { digest: "Alice", html: "Alice" },
    )
  end

  it "correctly finds the winner after one elimination" do
    votes = [
      %w[Alice Bob Charlie],
      %w[Bob Charlie Alice],
      %w[Charlie Alice Bob],
      %w[Charlie Alice Bob],
      %w[Bob Charlie Alice],
    ]
    expect(described_class.run(votes, options_2)[:winning_candidate]).to eq(
      { digest: "Bob", html: "Bob" },
    )
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
    expect(described_class.run(votes, options_3)[:tied_candidates]).to eq(
      [{ digest: "Bob", html: "Bob" }, { digest: "Dave", html: "Dave" }],
    )
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
    expect(described_class.run(votes, options_3)[:round_activity].length).to eq(2)
  end

  it "handles the winner with a simple majority" do
    votes = [%w[Dave Alice], %w[Bob Dave]]
    expect(described_class.run(votes, options_3)[:tied_candidates]).to eq(
      [{ digest: "Dave", html: "Dave" }, { digest: "Bob", html: "Bob" }],
    )
  end
end
