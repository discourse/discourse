# frozen_string_literal: true

RSpec.describe "Running Sidekiq Jobs in Multisite", type: :multisite do
  it "reverts to the default connection" do
    expect do Jobs::DestroyOldDeletionStubs.new.perform({}) end.to_not change {
      RailsMultisite::ConnectionManagement.current_db
    }
  end

  it "CheckNewFeatures should only hit the payload once" do
    # otherwise it will get rate-limited by meta
    DiscourseUpdates.expects(:new_features_response_json).returns([]).once
    Jobs::CheckNewFeatures.new.perform({})
  end
end

RSpec.describe Jobs::Scheduled, type: :multisite do
  describe "#perform" do
    let(:visited_sites) { [] }
    let(:job_class) do
      visited_sites = self.visited_sites
      Class.new(described_class) do
        define_method(:execute) do |_args|
          visited_sites << RailsMultisite::ConnectionManagement.current_db
        end
      end
    end

    after do
      Sidekiq.unpause_all!
      RailsMultisite::ConnectionManagement.each_connection { Discourse.disable_readonly_mode }
    end

    it "skips sites where Sidekiq is paused" do
      test_multisite_connection("second") { Sidekiq.pause!("restore") }

      job_class.new.perform

      expect(visited_sites).to contain_exactly("default")
    end

    it "skips sites in readonly mode" do
      Discourse.enable_readonly_mode

      job_class.new.perform

      expect(visited_sites).to contain_exactly("second")
    end
  end
end
