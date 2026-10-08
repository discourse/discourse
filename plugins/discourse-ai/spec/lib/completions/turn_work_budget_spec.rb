# frozen_string_literal: true

RSpec.describe DiscourseAi::Completions::TurnWorkBudget do
  describe "#generation_options" do
    it "allocates output without mutating caller options or increasing work" do
      budget = described_class.new(limit: 4000)
      options = { thinking_effort: "high", response_format: { type: "json_object" } }

      expect(budget.generation_options(options, maximum: 5000)).to eq(
        options.merge(max_tokens: 4000, max_tokens_is_total: true),
      )
      expect(budget.generation_options(options, maximum: 5000, tools: true)[:max_tokens]).to eq(
        2000,
      )
      expect(budget.generation_options(options, maximum: 1000, tools: true)[:max_tokens]).to eq(
        1000,
      )
      budget.debit(3999, event_id: "output")
      expect(budget.generation_options(options, maximum: 5000, tools: true)[:max_tokens]).to eq(1)
      expect(options).to eq(thinking_effort: "high", response_format: { type: "json_object" })
      expect(budget.limit).to eq(4000)
    end

    it "caps finals and disables thinking while only roots can allocate beyond remaining work" do
      budget = described_class.new(limit: 4000, used: 3500)
      options = { thinking_effort: "high" }

      expect(budget.generation_options(options, maximum: 5000, final: true, root: true)).to eq(
        max_tokens: 2048,
        max_tokens_is_total: true,
        thinking_effort: "none",
      )
      expect(
        budget.generation_options(options, maximum: 1000, final: true, root: true)[:max_tokens],
      ).to eq(1000)
      expect(budget.generation_options(options, maximum: 5000, final: true)[:max_tokens]).to eq(500)
      expect(budget.remaining).to eq(500)
    end
  end

  describe "#reserve_generation_output" do
    it "reserves the larger provider ceiling and retains strict helper admission" do
      budget = described_class.new(limit: 4000)
      reservation = budget.reserve_generation_output(2500, max_tokens: 2000)
      expect(budget.remaining).to eq(1500)
      expect { budget.reserve_generation_output(1600, max_tokens: 1000) }.to raise_error(
        DiscourseAi::Completions::ContextPreparation::Error,
        /turn_budget_exhausted/,
      )
      budget.release_output(reservation)
      reservation = budget.reserve_generation_output(nil, max_tokens: 2000)
      expect(budget.remaining).to eq(2000)
      budget.release_output(reservation)
      expect(budget.snapshot[:used]).to eq(0)
    end

    it "preserves root-only soft overshoot and checks children against local and root work" do
      budget = described_class.new(limit: 4000, used: 3500)
      child = budget.child(limit: 1000)
      expect { child.reserve_generation_output(600, max_tokens: 500) }.to raise_error(
        DiscourseAi::Completions::ContextPreparation::Error,
        /turn_budget_exhausted/,
      )
      reservation = budget.reserve_generation_output(600, max_tokens: 500, root: true)
      expect(reservation.tokens).to eq(500)
      budget.release_output(reservation)
      expect(budget.remaining).to eq(500)
    end

    it "validates before claiming a root final and releases duplicate-final reservations" do
      budget = described_class.new(limit: 4000, used: 4500)
      expect {
        budget.reserve_generation_output(2049, max_tokens: 2048, final: true, root: true)
      }.to raise_error(DiscourseAi::Completions::ContextPreparation::Error, /final_output_limit/)
      expect(budget.snapshot[:final_answer_claimed]).to eq(false)

      reservation =
        budget.reserve_generation_output(2048, max_tokens: 2048, final: true, root: true)
      expect(reservation.tokens).to eq(2048)
      budget.release_output(reservation)
      expect(
        budget.reserve_generation_output(2048, max_tokens: 2048, final: true, root: true),
      ).to eq(nil)
      expect(budget.snapshot).to include(used: 4500, final_answer_claimed: true)
    end
  end

  it "charges fresh identical events but ignores replay without refunding work" do
    budget = described_class.new(limit: 4000)
    expect(budget.debit(2500, event_id: "read:1")).to eq(true)
    expect(budget.debit(2500, event_id: "read:1")).to eq(false)
    budget.debit(2500, event_id: "read:2")
    expect(budget.used).to eq(5000)
    expect(budget.remaining).to eq(0)
    restored = described_class.new(**budget.snapshot)
    expect(restored.debit(2500, event_id: "read:2")).to eq(false)
    expect(restored.used).to eq(5000)
  end

  it "shares nested allocations while isolating sibling work from local ceilings" do
    root = described_class.new(limit: 4000)
    child = root.child(limit: 2000)
    sibling = root.child(limit: 2000)
    grandchild = child.child(limit: 1000)
    grandchild.debit(700, event_id: "grandchild:generation")
    sibling.debit(1200, event_id: "sibling:generation")
    expect([root.used, child.used, sibling.used, grandchild.used]).to eq([1900, 700, 1200, 700])
    expect([root.remaining, child.remaining, sibling.remaining, grandchild.remaining]).to eq(
      [2100, 1300, 800, 300],
    )
  end

  it "atomically reserves concurrent output rather than multiplying child allowances" do
    root = described_class.new(limit: 4000)
    children = 4.times.map { root.child(limit: 4000) }
    ready = Queue.new
    start = Queue.new
    threads =
      children.map do |child|
        Thread.new do
          ready << true
          start.pop
          child.reserve_output(1500)
        end
      end
    4.times { ready.pop }
    4.times { start << true }
    reservations = threads.map(&:value)
    expect(reservations.compact.size).to eq(2)
    expect(root.remaining).to eq(1000)
    children
      .zip(reservations)
      .each do |child, reservation|
        child.release_output(reservation)
        child.release_output(reservation)
      end
    expect(root.remaining).to eq(4000)
    expect(root.reserve_output(-100)).to be_nil
    expect(root.remaining).to eq(4000)
  ensure
    threads&.each(&:kill)
  end

  it "settles concurrent child debits and reservations without lost or duplicated events" do
    root = described_class.new(limit: 4000)
    children = 4.times.map { root.child(limit: 1000) }
    ready = Queue.new
    start = Queue.new
    threads =
      children.each_with_index.map do |child, index|
        Thread.new do
          reservation = child.reserve_output(1000)
          ready << reservation
          start.pop
          child.debit(750, event_id: "child:#{index}")
          child.debit(100, event_id: "shared accepted event")
          child.release_output(reservation)
        end
      end
    reservations = 4.times.map { ready.pop }
    expect(reservations.compact.size).to eq(4)
    expect(root.remaining).to eq(0)
    4.times { start << true }
    threads.each(&:value)
    expect(root.used).to eq(3100)
    expect(root.remaining).to eq(900)
    expect(children.map(&:used).sort).to eq([750, 750, 750, 850])
    expect(root.snapshot[:event_ids].size).to eq(5)
  ensure
    threads&.each(&:kill)
  end

  it "allows only one owning-root final answer and persists that claim" do
    root = described_class.new(limit: 4000, used: 5000)
    expect(root.child(limit: 1000).claim_final_answer).to eq(false)
    expect(root.claim_final_answer).to eq(true)
    reservation = root.reserve_output(2048, final: true)
    expect(reservation.tokens).to eq(2048)
    expect { root.snapshot }.to raise_error(ArgumentError, /in-flight/)
    root.debit(2048, event_id: "final")
    root.release_output(reservation)
    restored = described_class.new(**root.snapshot)
    expect(restored.used).to eq(7048)
    expect(restored.claim_final_answer).to eq(false)
  end
end
