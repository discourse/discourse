# frozen_string_literal: true

RSpec.describe "Nested timeline visual map" do
  include ThemeScreenshotMarker

  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:topic) { Fabricate(:topic, user: user, title: "How should threaded discussions scale?") }
  fab!(:op) do
    Fabricate(
      :post,
      topic: topic,
      user: user,
      post_number: 1,
      raw: "Compare the different shapes of discussion below.",
    )
  end
  fab!(:nested_topic_record) { Fabricate(:nested_topic, topic: topic) }

  let(:nested_view) { PageObjects::Pages::NestedView.new }

  before do
    SiteSetting.nested_replies_enabled = true
    SiteSetting.nested_replies_max_depth = 3
    sign_in(user)
  end

  it "helps the user compare branch size and nesting depth",
     time: Time.zone.parse("2026-08-21 12:00:00") do
    wide_root = create_root("A broad question with many direct answers", created_at: 12.hours.ago)
    12.times do |index|
      create_child(
        wide_root,
        "Independent answer #{index + 1}",
        created_at: 11.hours.ago + index.minutes,
      )
    end

    4.times do |index|
      create_root("A branch without replies #{index + 1}", created_at: (10 - index).hours.ago)
    end

    medium_root = create_root("A focused three-level discussion", created_at: 6.hours.ago)
    create_chain(medium_root, depth: 3, created_at: 5.hours.ago)

    5.times do |index|
      create_root("Another branch without replies #{index + 1}", created_at: (4 - index).hours.ago)
    end

    deep_root =
      create_root("A discussion that continues beyond the preview", created_at: 1.minute.ago)
    create_chain(deep_root, depth: 6, created_at: 50.seconds.ago)

    nested_view.use_wide_timeline_viewport
    nested_view.visit_nested(topic, query: "sort=old")

    expect(nested_view).to have_timeline
    expect(nested_view).to have_timeline_marks(count: 3)
    expect(nested_view).to have_timeline_legend
    expect(nested_view).to have_timeline_branch_summary("12 replies · 1 level deep")
    legend_rows = nested_view.timeline_legend_rows
    expect(legend_rows.pluck("top").uniq.length).to eq(4)
    expect(legend_rows.pluck("symbolWidth")).to all(be > 20)
    expect(legend_rows.pluck("painted")).to all(be(true))

    screenshot_marker(label: "nested-timeline-wide-branch", only: :desktop)

    nested_view.jump_to_last_timeline_branch

    expect(nested_view).to have_timeline_branch_summary("6 replies · 5+ levels deep")

    screenshot_marker(label: "nested-timeline-deep-branch", only: :desktop)
  end

  it "shows the gutter from its breakpoint and never overflows the page" do
    create_root("A branch with replies", created_at: 2.hours.ago).then do |root|
      create_child(root, "A reply", created_at: 1.hour.ago)
    end

    nested_view.use_narrow_timeline_viewport
    nested_view.visit_nested(topic, query: "sort=old")

    expect(nested_view).to have_nested_view
    expect(nested_view).to have_no_timeline
    expect(nested_view).to have_no_horizontal_overflow

    nested_view.use_timeline_breakpoint_viewport

    expect(nested_view).to have_timeline
    expect(nested_view).to have_no_horizontal_overflow
  end

  private

  def create_root(raw, created_at:)
    Fabricate(:post, topic: topic, user: Fabricate(:user), raw: raw, created_at: created_at)
  end

  def create_child(parent, raw, created_at:)
    Fabricate(
      :post,
      topic: topic,
      user: Fabricate(:user),
      raw: raw,
      reply_to_post_number: parent.post_number,
      created_at: created_at,
    )
  end

  def create_chain(parent, depth:, created_at:)
    depth.times do |index|
      parent =
        create_child(
          parent,
          "Nested follow-up #{index + 1}",
          created_at: created_at + index.seconds,
        )
    end
  end
end
