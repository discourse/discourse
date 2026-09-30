# frozen_string_literal: true

RSpec.describe DiscourseVips::Client do
  def call_version
    described_class.call(["version"], operation: :vips_version, read: [], write: [])
  end

  around do |example|
    shared_worker = described_class.instance_variable_get(:@shared_worker)
    example.run
  ensure
    described_class.instance_variable_set(:@shared_worker, shared_worker)
  end

  context "with the shared worker" do
    before { described_class.instance_variable_set(:@shared_worker, true) }

    it "retries while the worker is unavailable" do
      described_class
        .expects(:send_command)
        .times(3)
        .raises(DiscourseVips::WorkerUnavailable)
        .then
        .raises(DiscourseVips::WorkerUnavailable)
        .then
        .returns({ "status" => "ok", "value" => "8.15.0" })

      expect(call_version).to eq("8.15.0")
    end

    it "gives up once the retry budget is spent" do
      described_class.stubs(:send_command).raises(DiscourseVips::WorkerUnavailable)

      stub_const(described_class, :SHARED_WORKER_RETRY_SECONDS, 0.3) do
        expect { call_version }.to raise_error(DiscourseVips::WorkerUnavailable)
      end
    end
  end

  it "does not retry a private worker" do
    described_class.instance_variable_set(:@shared_worker, false)
    described_class.expects(:send_command).once.raises(DiscourseVips::WorkerUnavailable)

    expect { call_version }.to raise_error(DiscourseVips::WorkerUnavailable)
  end
end
