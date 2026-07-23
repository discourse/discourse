# frozen_string_literal: true

require "rails_helper"
require "rake"

# rubocop:disable RSpec/DescribeClass
RSpec.describe "s3:upload_assets rake task" do
  before do
    Rake::Task.clear
    Discourse::Application.load_tasks
  end

  let(:task) { Rake::Task["s3:upload_assets"] }
  let(:logger) { instance_double(Logger) }
  before do
    allow(Logger).to receive(:new).and_return(logger)
    allow(logger).to receive(:<<)
    allow(logger).to receive(:error)

    # Stub S3 configuration check
    allow(GlobalSetting).to receive(:use_s3?).and_return(true)

    # Stub S3 site settings
    SiteSetting.s3_upload_bucket = "test-bucket"
    SiteSetting.s3_region = "us-east-1"

    allow_any_instance_of(Object).to receive(:assets).and_return([])
    allow_any_instance_of(Object).to receive(:existing_assets).and_return(Set.new)

    # Skip CORS rules task completely to avoid S3 calls
    allow(S3CorsRulesets).to receive(:sync).and_return(nil)
  end

  describe "error handling" do
    let(:test_assets) do
      [
        %w[/tmp/asset1.js assets/asset1-abc.js application/javascript],
        %w[/tmp/asset2.css assets/asset2-def.css text/css],
        %w[/tmp/asset3.js assets/asset3-ghi.js application/javascript],
      ]
    end

    before { allow_any_instance_of(Object).to receive(:assets).and_return(test_assets) }

    it "fails the task when any upload fails" do
      call_count = 0
      allow_any_instance_of(Object).to receive(:upload) do |*args|
        call_count += 1
        raise "S3 connection timeout" if call_count == 2 # Second upload fails
      end

      expect { task.invoke }.to raise_error(/Asset upload failed/)
    end

    it "reports all failures when multiple uploads fail" do
      allow_any_instance_of(Object).to receive(:upload) do
        raise "S3 connection timeout"
      end

      expect { task.invoke }.to raise_error(/Asset upload failed/)
      expect(logger).to have_received(:error).with(/3 asset upload\(s\) failed/)
    end

    it "succeeds when all uploads succeed" do
      allow_any_instance_of(Object).to receive(:upload)

      expect { task.invoke }.not_to raise_error
    end
  end

  describe "parallelization" do
    let(:test_assets) do
      Array.new(10) do |i|
        ["/tmp/asset#{i}.js", "assets/asset#{i}-abc.js", "application/javascript"]
      end
    end

    before do
      allow_any_instance_of(Object).to receive(:assets).and_return(test_assets)
      allow_any_instance_of(Object).to receive(:upload)
    end

    it "uses a thread pool for concurrent uploads" do
      pool = instance_double(Concurrent::FixedThreadPool)
      allow(Concurrent::FixedThreadPool).to receive(:new).and_return(pool)
      allow(pool).to receive(:shutdown)
      allow(pool).to receive(:wait_for_termination)

      # Mock promises
      promise = instance_double(Concurrent::Promise, rejected?: false)
      allow(Concurrent::Promise).to receive(:execute).and_return(promise)

      task.invoke

      expect(Concurrent::FixedThreadPool).to have_received(:new)
      expect(pool).to have_received(:shutdown)
      expect(pool).to have_received(:wait_for_termination)
    end

    it "uses eight upload threads" do
      allow(Concurrent::FixedThreadPool).to receive(:new).with(8).and_call_original

      task.invoke

      expect(Concurrent::FixedThreadPool).to have_received(:new).with(8)
    end
  end

  describe "S3 pre-warming" do
    let(:test_assets) { [%w[/tmp/asset1.js assets/asset1-abc.js application/javascript]] }

    before do
      allow_any_instance_of(Object).to receive(:assets).and_return(test_assets)
      allow_any_instance_of(Object).to receive(:upload)
    end

    it "loads existing assets before spawning threads" do
      existing_assets_loaded = false
      threads_spawned = false

      allow_any_instance_of(Object).to receive(:existing_assets) do
        existing_assets_loaded = true
        expect(threads_spawned).to be_falsey
        Set.new
      end

      original_new = Concurrent::FixedThreadPool.method(:new)
      allow(Concurrent::FixedThreadPool).to receive(:new) do |*args|
        threads_spawned = true
        expect(existing_assets_loaded).to be_truthy
        original_new.call(*args)
      end

      task.invoke
    end
  end
end
# rubocop:enable RSpec/DescribeClass
