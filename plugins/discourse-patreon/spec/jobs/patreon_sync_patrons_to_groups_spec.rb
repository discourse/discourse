# frozen_string_literal: true

RSpec.describe Jobs::PatreonSyncPatronsToGroups do
  before do
    SiteSetting.patreon_enabled = true
    SiteSetting.patreon_creator_access_token = "TOKEN"
    SiteSetting.patreon_creator_refresh_token = "TOKEN"
  end

  it "creates a PatreonSyncLog after sync" do
    Patreon::Patron.stubs(:update!)

    expect { described_class.new.execute({}) }.to change { PatreonSyncLog.count }.by(1)

    log = PatreonSyncLog.last
    expect(log.synced_at).to be_within(5.seconds).of(Time.now)
  end

  it "does not run when patreon is disabled" do
    SiteSetting.patreon_enabled = false
    Patreon::Patron.expects(:update!).never

    described_class.new.execute({})

    expect(PatreonSyncLog.count).to eq(0)
  end

  it "accumulates sync logs across multiple runs" do
    Patreon::Patron.stubs(:update!)

    described_class.new.execute({})
    described_class.new.execute({})

    expect(PatreonSyncLog.count).to eq(2)
  end
end
