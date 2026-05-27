# frozen_string_literal: true

RSpec.describe DiscourseAi::Completions::TokenUsageTracker do
  it "applies weighted request accounting from audit logs" do
    tracker = described_class.new
    log =
      Struct.new(:request_tokens, :cache_write_tokens, :cache_read_tokens, :response_tokens).new(
        1000,
        0,
        800,
        50,
      )

    tracker.add_from_audit_log(log)

    expect(tracker.request).to eq(1080)
    expect(tracker.response).to eq(50)
    expect(tracker.total).to eq(1130)
  end

  it "supports starting from a previous total budget" do
    tracker = described_class.new(base_total: 101)

    expect(tracker.request).to eq(50)
    expect(tracker.response).to eq(51)
    expect(tracker.total).to eq(101)
  end

  it "supports exact request/response initialization" do
    tracker = described_class.new(base_request: 12, base_response: 34)

    expect(tracker.request).to eq(12)
    expect(tracker.response).to eq(34)
    expect(tracker.total).to eq(46)
  end

  it "accumulates across multiple audit logs" do
    tracker = described_class.new
    log = Struct.new(:request_tokens, :cache_write_tokens, :cache_read_tokens, :response_tokens)

    tracker.add_from_audit_log(log.new(100, 20, 50, 10))
    tracker.add_from_audit_log(log.new(200, 0, 0, 5))

    expect(tracker.request).to eq(325)
    expect(tracker.response).to eq(15)
    expect(tracker.total).to eq(340)
  end

  it "raises when request/response initialization is partial" do
    expect { described_class.new(base_request: 1) }.to raise_error(
      ArgumentError,
      /must both be provided/,
    )
  end

  it "raises when total and request/response are mixed" do
    expect {
      described_class.new(base_total: 10, base_request: 1, base_response: 2)
    }.to raise_error(ArgumentError, /cannot be combined/)
  end
end
