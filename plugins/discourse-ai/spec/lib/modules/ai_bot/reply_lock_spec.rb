# frozen_string_literal: true

RSpec.describe DiscourseAi::AiBot::ReplyLock do
  before { enable_current_plugin }

  it "reenters the same scope and releases ownership after an exception" do
    key = "discourse_ai:reply:lock-spec"
    DistributedMutex.any_instance.stubs(:sleep).raises("Unexpected lock wait")
    expect {
      described_class.synchronize(key) do
        described_class.synchronize(key) { raise "Nested failure" }
      end
    }.to raise_error("Nested failure")
    expect(Discourse.redis.get(key)).to be_nil
    expect(described_class.synchronize(key) { :released }).to eq(:released)
  end

  it "serializes independent threads even when the owner reenters" do
    key = "discourse_ai:reply:lock-concurrency-spec"
    attempts = Queue.new
    order = Queue.new
    worker = nil
    described_class.synchronize(key) do
      described_class.synchronize(key) do
        worker =
          Thread.new do
            attempts << true
            described_class.synchronize(key) { order << :other_thread }
          end
        attempts.pop
        expect(worker.join(0.05)).to be_nil
        order << :owner
      end
    end
    expect(worker.join(3)).to eq(worker)
    expect([order.pop, order.pop]).to eq(%i[owner other_thread])
  ensure
    worker&.kill if worker&.alive?
    worker&.join
  end
end
