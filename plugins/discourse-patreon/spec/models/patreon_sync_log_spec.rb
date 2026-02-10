# frozen_string_literal: true

RSpec.describe PatreonSyncLog do
  it "creates with synced_at" do
    log = PatreonSyncLog.create!(synced_at: Time.current)
    expect(log).to be_persisted
    expect(log.synced_at).to be_present
  end

  it "orders by synced_at descending" do
    old = PatreonSyncLog.create!(synced_at: 2.hours.ago)
    recent = PatreonSyncLog.create!(synced_at: 1.hour.ago)

    expect(PatreonSyncLog.order(synced_at: :desc).first).to eq(recent)
  end
end
