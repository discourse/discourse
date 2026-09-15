# frozen_string_literal: true

RSpec.describe Jobs::SyncBadgeAvailability, type: :multisite do
  it "coalesces independently for each site" do
    RailsMultisite::ConnectionManagement.safe_each_connection do
      DB.test_transaction = ActiveRecord::Base.connection.current_transaction
      2.times { described_class.enqueue }
    end

    DB.test_transaction = ActiveRecord::Base.connection.current_transaction

    expect(
      described_class.jobs.map { |job| job["args"].first["current_site_id"] },
    ).to contain_exactly("default", "second")
  end
end
