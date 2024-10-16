# frozen_string_literal: true

RSpec.describe "Running Sidekiq Jobs in Multisite", type: :multisite do
  it "should revert back to the default connection" do
    expect do Jobs::DestroyOldDeletionStubs.new.perform({}) end.to_not change {
      RailsMultisite::ConnectionManagement.current_db
    }
  end

  it "CheckNewFeatures should only hit the payload once" do
    # otherwise it will get rate-limited by meta
    DiscourseUpdates.expects(:new_features_payload).returns([]).once
    Jobs::CheckNewFeatures.new.perform({})
  end
end
