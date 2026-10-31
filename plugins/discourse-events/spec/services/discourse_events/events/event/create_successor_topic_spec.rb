# frozen_string_literal: true

RSpec.describe DiscourseEvents::Events::Event::CreateSuccessorTopic do
  fab!(:author) { Fabricate(:user, admin: true, refresh_auto_groups: true) }
  fab!(:category, :category)

  before do
    SiteSetting.discourse_events_enabled = true
    SiteSetting.discourse_post_event_enabled = true
    SiteSetting.discourse_post_event_recurring_topic_mode = "create_next_topic"
  end

  it "rejects an unknown occurrence via a model failure" do
    result = described_class.call(params: { event_date_id: 0 })

    expect(result).to fail_to_find_a_model(:event_date)
  end

  it "refuses to republish a source with no original author" do
    source_post = instance_double(Post, topic: instance_double(Topic), user: nil)
    event = instance_double(DiscourseEvents::Events::Event, post: source_post)

    expect(described_class.rollover_allowed?(event)).to eq(false)
  end

  it "rejects a hidden source post via its rollover policy" do
    starts_at = 7.days.after.change(sec: 0)
    ends_at = starts_at + 1.hour
    post =
      PostCreator.create!(
        author,
        title: "Ineligible recurring event",
        category: category.id,
        raw: <<~RAW,
          [event start="#{starts_at.utc.strftime("%Y-%m-%d %H:%M")}" end="#{ends_at.utc.strftime("%Y-%m-%d %H:%M")}" status="public" timezone="UTC" recurrence="every_week"]
          Meeting notes.
          [/event]
        RAW
      )
    event_date = post.reload.event.event_dates.pending.first
    original_raw = post.raw
    post.update_columns(hidden: true)

    result = described_class.call(params: { event_date_id: event_date.id })

    expect(result).to fail_a_policy(:rollover_allowed)
    expect(post.reload.raw).to eq(original_raw)
    expect(event_date.reload.finished_at).to be_nil
  end

  it "archives initial-capital Event recurrence aliases as a one-off" do
    starts_at = 7.days.after.change(sec: 0)
    ends_at = starts_at + 1.hour
    until_at = starts_at + 4.weeks
    title = "Mixed-case recurrence rollover"
    post = PostCreator.create!(author, title:, category: category.id, raw: <<~RAW)
          [event start="#{starts_at.utc.strftime("%Y-%m-%d %H:%M")}" end="#{ends_at.utc.strftime("%Y-%m-%d %H:%M")}" status="public" timezone="UTC" Recurrence="every_week" RecurrenceUntil="#{until_at.utc.strftime("%Y-%m-%d %H:%M")}"]
          Meeting notes.
          [/event]
        RAW
    event_date = post.reload.event.event_dates.pending.first

    expect(post.event.recurrence).to eq("every_week")

    expect do
      result = described_class.call(params: { event_date_id: event_date.id })
      expect(result).to run_successfully
    end.to change(Topic, :count).by(1)

    archived = post.reload
    expect(archived.raw).not_to match(/\bRecurrence(?:Until)?=/)
    expect(archived.event.reload.recurrence).to be_nil
    expect(archived.event.recurrence_until).to be_nil

    successor = Topic.where(title:).where.not(id: post.topic_id).sole
    expect(successor.first_post.reload.event.recurrence).to eq("every_week")
  end

  it "does not retry an archival revision that fails for another reason" do
    starts_at = 7.days.after.change(sec: 0)
    ends_at = starts_at + 1.hour
    title = "Archive validation failure"
    post = PostCreator.create!(author, title:, category: category.id, raw: <<~RAW)
          [event start="#{starts_at.utc.strftime("%Y-%m-%d %H:%M")}" end="#{ends_at.utc.strftime("%Y-%m-%d %H:%M")}" status="public" timezone="UTC" recurrence="every_week"]
          Meeting notes.
          [/event]
        RAW
    event_date = post.reload.event.event_dates.pending.first
    original_raw = post.raw
    attempts = 0

    allow_any_instance_of(PostRevisor).to receive(:revise!) do |_revisor, *_args|
      attempts += 1
      false
    end

    expect do
      result = described_class.call(params: { event_date_id: event_date.id })
      expect(result.success?).to eq(false)
      expect(result["result.try.default"]&.exception).to be_a(ActiveRecord::RecordNotSaved)
    end.not_to change(Topic, :count)

    expect(attempts).to eq(1)
    expect(post.reload.raw).to eq(original_raw)
    expect(event_date.reload.finished_at).to be_nil
  end

  it "archives the occurrence and creates a successor" do
    starts_at = 7.days.after.change(sec: 0)
    ends_at = starts_at + 1.hour
    title = "Service-object rollover"
    post = PostCreator.create!(author, title:, category: category.id, raw: <<~RAW)
          [event start="#{starts_at.utc.strftime("%Y-%m-%d %H:%M")}" end="#{ends_at.utc.strftime("%Y-%m-%d %H:%M")}" status="public" timezone="UTC" recurrence="every_week"]
          Meeting notes.
          [/event]
        RAW
    event_date = post.reload.event.event_dates.pending.first

    expect do
      result = described_class.call(params: { event_date_id: event_date.id })
      expect(result).to run_successfully
    end.to change(Topic, :count).by(1)

    successor = Topic.where(title:).where.not(id: post.topic_id).sole
    expect(successor.first_post.reload.event.recurrence).to eq("every_week")
    expect(post.reload.raw).not_to include('recurrence="every_week"')
    expect(post.last_editor_id).to eq(author.id)
  end
end
