# frozen_string_literal: true

RSpec.describe Lovelace::Reporting do
  fab!(:user)
  fab!(:other_user, :user)

  before { enable_current_plugin }

  it "counts unique milestones across reversals, dismissal and configuration edits" do
    Lovelace::MemberChecklist.for_user(user)
    expect(described_class.summary["seen"]).to eq(0)
    Lovelace::MemberChecklist.update!(user, seen: true)
    Lovelace::MemberChecklist.update!(user, seen: true)
    Lovelace::Checklist::DEFAULT_ITEMS.each do |id|
      Lovelace::MemberChecklist.update!(user, item_id: id, completed: true)
    end
    Lovelace::MemberChecklist.update!(user, item_id: "profile", completed: false)
    Lovelace::MemberChecklist.update!(user, dismissed: true)
    Lovelace::MemberChecklist.update!(other_user, seen: true, dismissed: true)
    PluginStore.set(Lovelace::PLUGIN_NAME, "checklist", { "items" => [], "revision" => 1 })

    expect(described_class.summary).to eq(
      "seen" => 2,
      "engaged" => 1,
      "clicked" => 0,
      "clicked_all" => 0,
      "clicked_items" => {
      },
      "completed" => 1,
      "dismissed" => 2,
      "dismissed_without_completion" => 1,
      "items" => Lovelace::Checklist::DEFAULT_ITEMS.index_with { 1 },
    )
    expect(described_class.statistics).to include(
      "engaged_percent" => 50.0,
      "completed_percent" => 50.0,
      "dismissed_percent" => 100.0,
    )
  end

  it "filters cohorts by first display and keeps removed item completions" do
    freeze_time(Time.utc(2026, 1, 1)) do
      Lovelace::MemberChecklist.update!(user, seen: true, item_id: "profile", completed: true)
    end
    freeze_time(Time.utc(2026, 2, 1)) do
      Lovelace::MemberChecklist.update!(user, seen: true)
      Lovelace::MemberChecklist.update!(other_user, seen: true)
    end
    PluginStore.set(Lovelace::PLUGIN_NAME, "checklist", { "items" => [], "revision" => 1 })
    report =
      Report.find(
        "lovelace_onboarding_items",
        start_date: Time.utc(2026, 1, 1),
        end_date: Time.utc(2026, 1, 31).end_of_day,
      )
    expect(report.data).to eq([{ activity: "profile", clicked_count: 0, count: 1 }])
    expect(described_class.summary(start_date: Time.utc(2026, 2, 1))["seen"]).to eq(1)
  end

  it "exports aggregate configuration categories through standard statistics without item content" do
    custom =
      Lovelace::Checklist.seeded_items.first.merge(
        "id" => "custom-secret",
        "title" => "Private title",
        "url" => "/t/private/123",
        "link_type" => "topic",
      )
    PluginStore.set(
      Lovelace::PLUGIN_NAME,
      "checklist",
      { "items" => [Lovelace::Checklist.seeded_items.first, custom], "revision" => 1 },
    )
    stat = DiscoursePluginRegistry.stats.find { |entry| entry.name == "lovelace_onboarding" }
    expect(stat.expose_via_api).to eq(false)
    expect(stat.calculate).to include(
      lovelace_onboarding_enabled: 1,
      lovelace_onboarding_default_profile_picture: 1,
      lovelace_onboarding_default_profile: 0,
      lovelace_onboarding_custom_items: 1,
      lovelace_onboarding_custom_topic: 1,
      lovelace_onboarding_engaged_percent: 0.0,
    )
    expect(stat.calculate.values).to all(be_a(Numeric))
    SiteSetting.lovelace_enabled = false
    expect(stat.calculate[:lovelace_onboarding_enabled]).to eq(0)
    expect(DiscoursePluginRegistry.stats.map(&:name)).not_to include(stat.name)
  end

  it "does not invent impressions for hidden checklists or legacy state" do
    PluginStore.set(
      Lovelace::PLUGIN_NAME,
      "member_checklist_#{user.id}",
      { "completed_ids" => ["profile"], "dismissed" => true },
    )
    Lovelace::MemberChecklist.update!(user, seen: true)
    PluginStore.set(Lovelace::PLUGIN_NAME, "checklist", { "items" => [], "revision" => 1 })
    Lovelace::MemberChecklist.update!(other_user, seen: true)
    expect(described_class.summary["seen"]).to eq(0)
  end

  it "counts clicks separately from completions, once per member, and keeps removed item history" do
    Lovelace::MemberChecklist.update!(user, seen: true, clicked_item_id: "profile")
    Lovelace::MemberChecklist.update!(user, seen: true, clicked_item_id: "profile")
    expect(described_class.summary).to include(
      "clicked" => 1,
      "clicked_all" => 0,
      "engaged" => 0,
      "clicked_items" => {
        "profile" => 1,
      },
      "items" => {
      },
    )
    Lovelace::Checklist::DEFAULT_ITEMS.each do |id|
      Lovelace::MemberChecklist.update!(user, seen: true, clicked_item_id: id)
    end
    Lovelace::MemberChecklist.update!(other_user, seen: true, clicked_item_id: "profile")
    Lovelace::MemberChecklist.update!(other_user, item_id: "profile", completed: true)
    Lovelace::MemberChecklist.update!(other_user, item_id: "profile", completed: false)
    Lovelace::MemberChecklist.update!(user, dismissed: true)
    PluginStore.set(Lovelace::PLUGIN_NAME, "checklist", { "items" => [], "revision" => 1 })

    expect(described_class.summary).to include(
      "seen" => 2,
      "clicked" => 2,
      "clicked_all" => 1,
      "engaged" => 1,
      "dismissed_without_completion" => 1,
      "clicked_items" => {
        "profile" => 2,
        "profile_picture" => 1,
        "guidelines" => 1,
      },
      "items" => {
        "profile" => 1,
      },
    )
    report = Report.find("lovelace_onboarding_items")
    expect(report.data).to contain_exactly(
      { activity: "profile", clicked_count: 2, count: 1 },
      { activity: "profile_picture", clicked_count: 1, count: 0 },
      { activity: "guidelines", clicked_count: 1, count: 0 },
    )
    expect(described_class.statistics).to include("clicked" => 2, "clicked_all" => 1)
    expect(described_class.statistics.values).to all(be_a(Numeric))
  end

  it "keeps click activity in the first-display cohort and does not infer clicks for old state" do
    freeze_time(Time.utc(2026, 1, 1)) { Lovelace::MemberChecklist.update!(user, seen: true) }
    freeze_time(Time.utc(2026, 2, 1)) do
      Lovelace::MemberChecklist.update!(user, seen: true, clicked_item_id: "profile")
      Lovelace::MemberChecklist.update!(other_user, seen: true, item_id: "profile", completed: true)
    end
    expect(described_class.summary(end_date: Time.utc(2026, 1, 31).end_of_day)).to include(
      "seen" => 1,
      "clicked" => 1,
      "clicked_items" => {
        "profile" => 1,
      },
    )
    expect(described_class.summary(start_date: Time.utc(2026, 2, 1))).to include(
      "seen" => 1,
      "clicked" => 0,
      "clicked_items" => {
      },
    )
    Lovelace::Checklist::DEFAULT_ITEMS.each do |id|
      Lovelace::MemberChecklist.update!(other_user, item_id: id, completed: true)
    end
    expect(described_class.summary).to include("completed" => 1, "clicked_all" => 0)
  end
end
