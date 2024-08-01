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

  let(:options_4) do
    [
      { id: "Belle-lettres", html: "Belle-lettres" },
      { id: "Comedy", html: "Comedy" },
      { id: "Fantasy", html: "Fantasy" },
      { id: "Historical", html: "Historical" },
      { id: "Mystery", html: "Mystery" },
      { id: "Non-fiction", html: "Non-fiction" },
      { id: "Sci-fi", html: "Sci-fi" },
      { id: "Thriller", html: "Thriller" },
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

  it "handles a tie after an elimination" do
    votes = [%w[Dave Alice], %w[Bob Dave]]
    expect(described_class.run(votes, options_3)[:tied_candidates]).to eq(
      [{ digest: "Dave", html: "Dave" }, { digest: "Bob", html: "Bob" }],
    )
  end

  it "handles a complex multi-round tie" do
    votes = [
      %w[Belle-lettres Thriller Non-fiction Sci-fi Mystery Comedy Historical Fantasy],
      %w[Mystery Fantasy Belle-lettres Sci-fi Non-fiction Historical Thriller Comedy],
      %w[Mystery Thriller Belle-lettres Sci-fi Comedy Non-fiction Fantasy Historical],
      %w[Mystery Sci-fi Fantasy Thriller Non-fiction Belle-lettres Historical Comedy],
      %w[Mystery Thriller Non-fiction Sci-fi Comedy Historical Belle-lettres Fantasy],
      %w[Fantasy Non-fiction Mystery Sci-fi Thriller Historical Belle-lettres Comedy],
      %w[Fantasy Mystery Historical Thriller Sci-fi Non-fiction Comedy Belle-lettres],
      %w[Thriller Mystery Fantasy Non-fiction Sci-fi Historical Comedy Belle-lettres],
      %w[Mystery Fantasy Historical Thriller Non-fiction Comedy Sci-fi Belle-lettres],
      %w[Fantasy Sci-fi Thriller Mystery Non-fiction Comedy Historical Belle-lettres],
      %w[Fantasy Sci-fi Historical Non-fiction Comedy],
      %w[Fantasy Sci-fi Mystery Comedy Thriller Non-fiction Historical],
      %w[Fantasy Mystery Historical Non-fiction Sci-fi Comedy],
      %w[Fantasy Sci-fi Mystery Comedy Thriller Historical Non-fiction],
      %w[Comedy Historical Fantasy Sci-fi Mystery],
      %w[Sci-fi Thriller Mystery Non-fiction Comedy Fantasy],
    ]

    outcome = described_class.run(votes, options_4)

    expect(outcome[:tied_candidates]).to eq(
      [{ digest: "Mystery", html: "Mystery" }, { digest: "Fantasy", html: "Fantasy" }],
    )
    expect(outcome[:round_activity].length).to eq(3)
  end
end
