# frozen_string_literal: true

RSpec.describe Migrations::Importer::Uploads::RetryPolicy do
  # Stand-ins for the real (Rails/AWS) error classes, so the policy can be tested
  # without booting Rails.
  transient_error = Class.new(StandardError)
  permanent_error = Class.new(StandardError)
  duplicate_error = Class.new(StandardError)

  subject(:policy) do
    described_class.new(
      transient_errors: [transient_error, duplicate_error],
      max_attempts: 3,
      base_delay: 0.5,
      jitter: 0.25,
      sleeper: ->(seconds) { slept << seconds },
      rng:,
    )
  end

  let(:slept) { [] }
  # Deterministic jitter so the backoff assertions are exact.
  let(:rng) { instance_double(Random, rand: 0.1) }

  it "returns the value when the block succeeds on the first try" do
    expect(policy.run { 42 }).to eq(42)
    expect(slept).to be_empty
  end

  it "retries a transient error up to the attempt budget, then re-raises" do
    attempts = 0

    expect {
      policy.run do
        attempts += 1
        raise transient_error
      end
    }.to raise_error(transient_error)

    expect(attempts).to eq(4) # first try + 3 retries
    expect(slept).to eq([0.6, 1.1, 2.1]) # 0.5·2^n + 0.1 jitter
  end

  it "succeeds if a transient error clears within the budget" do
    attempts = 0

    result =
      policy.run do
        attempts += 1
        raise transient_error if attempts < 3
        :ok
      end

    expect(result).to eq(:ok)
    expect(attempts).to eq(3)
    expect(slept.size).to eq(2)
  end

  it "does not retry a permanent error" do
    attempts = 0

    expect {
      policy.run do
        attempts += 1
        raise permanent_error
      end
    }.to raise_error(permanent_error)

    expect(attempts).to eq(1)
    expect(slept).to be_empty
  end

  it "recovers a duplicate via the handler instead of re-running the block" do
    attempts = 0

    result =
      policy.run(recover: { duplicate_error => ->(_e) { :existing_row } }) do
        attempts += 1
        raise duplicate_error
      end

    expect(result).to eq(:existing_row)
    expect(attempts).to eq(1) # the block ran once; recovery replaced a redo
    expect(slept).to be_empty
  end

  it "falls back to a transient retry when the recover handler finds nothing" do
    attempts = 0

    expect {
      policy.run(recover: { duplicate_error => ->(_e) { nil } }) do
        attempts += 1
        raise duplicate_error
      end
    }.to raise_error(duplicate_error)

    expect(attempts).to eq(4) # handler returned nil, so it retried as transient
  end
end
