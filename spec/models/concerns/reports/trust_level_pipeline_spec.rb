# frozen_string_literal: true

describe Reports::TrustLevelPipeline do
  before { freeze_time(Time.zone.local(2026, 4, 28, 12, 0, 0)) }

  let(:start_date) { Time.zone.local(2026, 4, 1) }
  let(:end_date) { Time.zone.local(2026, 4, 28).end_of_day }

  def build
    Report.find("trust_level_pipeline", start_date: start_date, end_date: end_date)
  end

  def row(report, tl)
    report.data.find { |r| r[:trust_level] == tl }
  end

  def record_promotion(user, from:, to:, at:, action: :change_trust_level)
    UserHistory.create!(
      action: UserHistory.actions[action],
      target_user_id: user.id,
      previous_value: from.to_s,
      new_value: to.to_s,
      created_at: at,
    )
  end

  it "snapshots the current member count and share per trust level" do
    Fabricate(:user, trust_level: TrustLevel[1])
    Fabricate(:user, trust_level: TrustLevel[1])
    Fabricate(:user, trust_level: TrustLevel[2])
    Fabricate(:user, trust_level: TrustLevel[4])

    report = build

    expect(row(report, 1)[:count]).to eq(2)
    expect(row(report, 2)[:count]).to eq(1)
    expect(row(report, 4)[:count]).to eq(1)
    expect(report.data.sum { |r| r[:share] }).to be_within(0.1).of(100.0)
  end

  it "splits promotions and demotions into directional in/out flows per level" do
    user = Fabricate(:user, trust_level: TrustLevel[2])
    record_promotion(user, from: 1, to: 2, at: start_date + 1.day)
    record_promotion(user, from: 2, to: 3, at: start_date + 5.days)

    report = build

    expect(row(report, 2)[:promoted_in]).to eq(1)
    expect(row(report, 2)[:promoted_out]).to eq(1)
    expect(row(report, 3)[:promoted_in]).to eq(1)
    expect(row(report, 1)[:promoted_out]).to eq(1)
    expect(report.data.sum { |r| r[:demoted_in] + r[:demoted_out] }).to eq(0)
  end

  it "counts auto_trust_level_change as well as manual change_trust_level" do
    user = Fabricate(:user, trust_level: TrustLevel[2])
    record_promotion(user, from: 1, to: 2, at: start_date + 1.day, action: :auto_trust_level_change)

    report = build

    expect(row(report, 2)[:promoted_in]).to eq(1)
  end

  it "records a downward move as a demotion, not a promotion" do
    user = Fabricate(:user, trust_level: TrustLevel[1])
    record_promotion(user, from: 1, to: 2, at: start_date + 2.days)
    record_promotion(user, from: 2, to: 1, at: start_date + 8.days)

    report = build

    expect(row(report, 2)[:promoted_in]).to eq(1)
    expect(row(report, 2)[:demoted_out]).to eq(1)
    expect(row(report, 2)[:promoted_out]).to eq(0)
    expect(row(report, 1)[:promoted_out]).to eq(1)
    expect(row(report, 1)[:demoted_in]).to eq(1)
  end

  it "counts members who joined in the period as sign-ups at the entry level" do
    Fabricate(:user, created_at: start_date + 3.days)
    Fabricate(:user, created_at: start_date + 10.days)
    Fabricate(:user, created_at: start_date - 5.days)

    report = build

    entry = row(report, SiteSetting.default_trust_level)
    expect(entry[:signups]).to eq(2)
    expect(row(report, 4)[:signups]).to eq(0)
  end

  it "does not count new sign-ups as trust-level moves" do
    Fabricate(:user, created_at: start_date + 3.days)

    report = build

    expect(row(report, 0)[:promoted_in]).to eq(0)
    expect(row(report, 0)[:demoted_in]).to eq(0)
  end

  it "ignores history rows outside the period" do
    user = Fabricate(:user, trust_level: TrustLevel[2])
    record_promotion(user, from: 1, to: 2, at: start_date - 5.days)
    record_promotion(user, from: 2, to: 3, at: end_date + 5.days)

    report = build

    expect(row(report, 2)[:promoted_in]).to eq(0)
    expect(row(report, 3)[:promoted_in]).to eq(0)
  end

  it "excludes the system user and bots from the snapshot" do
    Discourse.system_user
    Fabricate(:user, trust_level: TrustLevel[1])

    report = build

    real_count = report.data.sum { |r| r[:count] }
    expect(real_count).to eq(1)
  end

  it "reports a climbing direction when net promotions exceed net demotions" do
    user_a = Fabricate(:user, trust_level: TrustLevel[2])
    user_b = Fabricate(:user, trust_level: TrustLevel[2])
    record_promotion(user_a, from: 1, to: 2, at: start_date + 1.day)
    record_promotion(user_b, from: 1, to: 2, at: start_date + 2.days)

    report = build

    expect(report.prev_period[:direction]).to eq("climbing")
    expect(report.prev_period[:net]).to be > 0
  end

  it "reports a stable direction when moves cancel out" do
    user_up = Fabricate(:user, trust_level: TrustLevel[2])
    user_down = Fabricate(:user, trust_level: TrustLevel[1])
    record_promotion(user_up, from: 1, to: 2, at: start_date + 1.day)
    record_promotion(user_down, from: 2, to: 1, at: start_date + 2.days)

    report = build

    expect(report.prev_period[:direction]).to eq("stable")
    expect(report.prev_period[:net]).to eq(0)
  end

  it "ignores history rows whose values aren't integer strings" do
    user = Fabricate(:user, trust_level: TrustLevel[2])
    UserHistory.create!(
      action: UserHistory.actions[:change_trust_level],
      target_user_id: user.id,
      previous_value: "not_a_number",
      new_value: "2",
      created_at: start_date + 1.day,
    )

    expect { build }.not_to raise_error
  end
end
