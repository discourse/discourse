# frozen_string_literal: true

RSpec.describe Jobs::Voice::PurgeOldSessions do
  fab!(:user)
  fab!(:partner, :user)
  fab!(:room, :voice_room)

  before { SiteSetting.voice_enabled = true }

  def create_session(created_at)
    Fabricate(:voice_session, user: user, room: room).tap do |session|
      session.update_columns(created_at: created_at)
    end
  end

  def create_co_presence(date)
    first, second = [user.id, partner.id].sort
    Voice::CoPresence.create!(
      user_id_1: first,
      user_id_2: second,
      date: date,
      total_seconds: 300,
      session_count: 1,
    )
  end

  it "deletes sessions and co-presence older than the retention period" do
    retention = SiteSetting.voice_session_retention_days
    old_session = create_session((retention + 1).days.ago)
    recent_session = create_session((retention - 1).days.ago)
    create_co_presence((retention + 1).days.ago.to_date)
    recent_co_presence = create_co_presence((retention - 1).days.ago.to_date)

    described_class.new.execute({})

    expect(Voice::Session.all).to contain_exactly(recent_session)
    expect(Voice::CoPresence.all).to contain_exactly(recent_co_presence)
    expect(Voice::Session.exists?(old_session.id)).to eq(false)
  end

  it "keeps three years of history by default" do
    kept = create_session(1094.days.ago)
    create_session(1096.days.ago)

    described_class.new.execute({})

    expect(Voice::Session.all).to contain_exactly(kept)
  end

  it "does nothing when voice is disabled" do
    SiteSetting.voice_enabled = false
    old_session = create_session(10.years.ago)

    described_class.new.execute({})

    expect(Voice::Session.exists?(old_session.id)).to eq(true)
  end
end
