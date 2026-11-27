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

  it "rejects a stale archival revision and retries with updated content" do
    starts_at = 7.days.after.change(sec: 0)
    ends_at = starts_at + 1.hour
    title = "Concurrent edit rollover"

    post = PostCreator.create!(author, title:, category: category.id, raw: <<~RAW)
      [event start="#{starts_at.utc.strftime("%Y-%m-%d %H:%M")}" end="#{ends_at.utc.strftime("%Y-%m-%d %H:%M")}" status="public" timezone="UTC" recurrence="every_week"]
      Meeting notes.
      [/event]
    RAW

    event_date = post.reload.event.event_dates.pending.first
    original_raw = post.raw
    edited_raw = "#{original_raw}\n\nA user edit made before retry."
    force_stale_snapshot = true

    allow_any_instance_of(PostRevisor).to receive(:revise!).and_wrap_original do |method, *args|
      options = args.fetch(2)

      expected = force_stale_snapshot ? original_raw : edited_raw
      expect(options.fetch(:expected_raw)).to eq(expected)

      if force_stale_snapshot
        force_stale_snapshot = false
        args[2] = options.merge(expected_raw: "stale snapshot")
      end

      method.call(*args)
    end

    expect do
      result = described_class.call(params: { event_date_id: event_date.id })
      expect(result.success?).to eq(false)
      expect(result["result.try.default"]&.exception).to be_a(ActiveRecord::RecordNotSaved)
    end.not_to change(Topic, :count)

    expect(force_stale_snapshot).to eq(false)
    expect(post.reload.raw).to eq(original_raw)
    expect(post.topic.reload.title).to eq(title)
    expect(event_date.reload.finished_at).to be_nil

    # A subsequent user edit is available when the rollover is retried.
    post.update_columns(raw: edited_raw)

    expect do
      result = described_class.call(params: { event_date_id: event_date.id })
      expect(result).to run_successfully
    end.to change(Topic, :count).by(1)

    successor = Topic.where(title:).where.not(id: post.topic_id).sole
    expect(successor.first_post.raw).to include("A user edit made before retry.")
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

  it "creates a successor when a fenced quoted decoy precedes the Event" do
    starts_at = 7.days.after.change(sec: 0)
    ends_at = starts_at + 1.hour
    title = "Fenced decoy recurring event"

    raw = <<~RAW
      ```
      [example text="
      ```

      [event start='#{starts_at.utc.strftime("%Y-%m-%d %H:%M")}' end='#{ends_at.utc.strftime("%Y-%m-%d %H:%M")}' status='public' timezone='UTC' recurrence='every_week']
      Meeting notes.
      [/event]

      "]: ordinary text
    RAW

    post = PostCreator.create!(author, title:, category: category.id, raw:)
    event_date = post.reload.event.event_dates.pending.first

    expect do
      result = described_class.call(params: { event_date_id: event_date.id })
      expect(result).to run_successfully
    end.to change(Topic, :count).by(1)

    archived = post.reload.raw
    expect(archived).to include('[example text="')
    expect(archived).not_to include("recurrence='every_week'")

    successor = Topic.where(title:).where.not(id: post.topic_id).sole
    expect(successor.first_post.reload.event.recurrence).to eq("every_week")
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

  it "links consecutive successor topics without accumulating continuation links" do
    freeze_time Time.utc(2027, 1, 1, 12)

    starts_at = Time.utc(2027, 1, 2, 12)
    ends_at = starts_at + 1.hour
    title = "Linked weekly occurrence"

    post = PostCreator.create!(author, title:, category: category.id, raw: <<~RAW)
      [event start="2027-01-02 12:00" end="2027-01-02 13:00" status="public" timezone="UTC" recurrence="every_week"]
      Original meeting notes.
      [/event]
    RAW

    original_topic = post.topic
    first_date = post.reload.event.event_dates.pending.first

    freeze_time(ends_at + 1.hour)

    expect do
      expect(described_class.call(params: { event_date_id: first_date.id })).to run_successfully
    end.to change(Topic, :count).by(1)

    second_topic = Topic.where(title:).where.not(id: original_topic.id).sole
    second_post = second_topic.first_post.reload

    original_url = post.reload.full_url
    first_link = "[#{original_topic.reload.markdown_link_title}](#{original_url})"
    first_prefix = "#{I18n.t("js.post.continue_discussion", postLink: first_link)}\n\n"

    expect(first_prefix).to start_with("Continuing the discussion from ")
    expect(second_post.raw).to include("\n\n[event")
    expect(second_post.raw).to start_with(first_prefix)
    expect(second_post.raw).to include("Original meeting notes.")
    expect(second_post.event.recurrence).to eq("every_week")

    expect(
      TopicLink.exists?(
        topic_id: second_topic.id,
        link_topic_id: original_topic.id,
        reflection: false,
      ),
    ).to eq(true)

    expect(
      TopicLink.exists?(
        topic_id: original_topic.id,
        link_topic_id: second_topic.id,
        reflection: true,
      ),
    ).to eq(true)

    second_date = second_post.event.event_dates.pending.first
    freeze_time(second_date.ends_at + 1.hour)

    expect do
      expect(described_class.call(params: { event_date_id: second_date.id })).to run_successfully
    end.to change(Topic, :count).by(1)

    third_topic = Topic.where(title:).where.not(id: [original_topic.id, second_topic.id]).sole
    third_post = third_topic.first_post.reload

    second_link = "[#{second_topic.reload.markdown_link_title}](#{second_post.reload.full_url})"
    second_prefix = "#{I18n.t("js.post.continue_discussion", postLink: second_link)}\n\n"

    expect(third_post.raw).to start_with(second_prefix)
    expect(third_post.raw).not_to include(first_prefix)
    expect(third_post.raw).not_to include(original_url)
    expect(third_post.raw).to include("Original meeting notes.")
    expect(third_post.event.recurrence).to eq("every_week")

    expect(second_post.reload.raw).to start_with(first_prefix)

    expect(
      TopicLink.exists?(
        topic_id: third_topic.id,
        link_topic_id: second_topic.id,
        reflection: false,
      ),
    ).to eq(true)

    expect(
      TopicLink.exists?(topic_id: second_topic.id, link_topic_id: third_topic.id, reflection: true),
    ).to eq(true)
  end

  it "skips missed occurrences when a rollover runs late" do
    freeze_time Time.utc(2026, 10, 1, 12)

    starts_at = Time.utc(2026, 10, 2, 12)
    ends_at = starts_at + 1.hour
    title = "Delayed weekly rollover"

    post = PostCreator.create!(author, title:, category: category.id, raw: <<~RAW)
      [event start="2026-10-02 12:00" end="2026-10-02 13:00" status="public" timezone="UTC" recurrence="every_week"]
      Weekly meeting.
      [/event]
    RAW
    event_date = post.reload.event.event_dates.pending.first

    # October 9 and 16 have passed. The next occurrence is October 23.
    freeze_time Time.utc(2026, 10, 20, 12)

    expect do
      result = described_class.call(params: { event_date_id: event_date.id })
      expect(result).to run_successfully
    end.to change(Topic, :count).by(1)

    successor = Topic.where(title:).where.not(id: post.topic_id).sole
    expect(successor.first_post.reload.event.original_starts_at).to eq_time(
      Time.utc(2026, 10, 23, 12),
    )
    expect(post.reload.event.recurrence).to be_nil
  end

  it "archives the final occurrence without a successor when the series has ended" do
    freeze_time Time.utc(2026, 10, 1, 12)

    title = "Expired weekly rollover"
    post = PostCreator.create!(author, title:, category: category.id, raw: <<~RAW)
      [event start="2026-10-02 12:00" end="2026-10-02 13:00" status="public" timezone="UTC" recurrence="every_week" recurrence-until="2026-10-16 12:00"]
      Weekly meeting.
      [/event]
    RAW
    event_date = post.reload.event.event_dates.pending.first

    # The final scheduled occurrence has already passed.
    freeze_time Time.utc(2026, 10, 24, 12)

    expect do
      result = described_class.call(params: { event_date_id: event_date.id })
      expect(result).to run_successfully
    end.not_to change(Topic, :count)

    expect(post.reload.event.recurrence).to be_nil
    expect(post.raw).not_to include('recurrence="every_week"')
    expect(post.raw).not_to include("recurrence-until=")
  end

  it "preserves distinct UTC offsets when archiving a DST fall-back occurrence" do
    freeze_time Time.utc(2026, 10, 30, 12)

    starts_at = Time.iso8601("2026-11-01T01:30:00-04:00")
    ends_at = Time.iso8601("2026-11-01T01:30:00-05:00")
    title = "DST fall-back rollover"

    post = PostCreator.create!(author, title:, category: category.id, raw: <<~RAW)
      [event start="2026-11-01 01:30:00 -04:00" end="2026-11-01 01:30:00 -05:00" status="public" timezone="America/New_York" recurrence="every_week"]
      Meeting across the repeated hour.
      [/event]
    RAW

    event_date = post.reload.event.event_dates.pending.first
    expect(event_date.starts_at).to eq_time(starts_at)
    expect(event_date.ends_at).to eq_time(ends_at)

    freeze_time(ends_at + 1.hour)

    expect do
      result = described_class.call(params: { event_date_id: event_date.id })
      expect(result).to run_successfully
    end.to change(Topic, :count).by(1)

    archived = post.reload
    expect(archived.raw).to include('start="2026-11-01 01:30:00 -04:00"')
    expect(archived.raw).to include('end="2026-11-01 01:30:00 -05:00"')
    expect(archived.event.reload.original_starts_at).to eq_time(starts_at)
    expect(archived.event.original_ends_at).to eq_time(ends_at)
    # The scheduled monitor, not this service, marks the occurrence finished.
    expect(event_date.reload.finished_at).to be_nil

    successor = Topic.where(title:).where.not(id: post.topic_id).sole
    expect(successor.first_post.reload.event.recurrence).to eq("every_week")
  end

  it "preserves the original last-Monday rule when listing successor occurrences" do
    freeze_time Time.utc(2026, 8, 1, 12)

    starts_at = Time.utc(2026, 8, 31, 12)
    ends_at = starts_at + 1.hour
    title = "Monthly last-Monday rollover"

    post = PostCreator.create!(author, title:, category: category.id, raw: <<~RAW)
          [event start="#{starts_at.utc.strftime("%Y-%m-%d %H:%M")}" end="#{ends_at.utc.strftime("%Y-%m-%d %H:%M")}" status="public" timezone="UTC" recurrence="every_month"]
          Monthly meeting notes.
          [/event]
        RAW

    event_date = post.reload.event.event_dates.pending.first

    expect do
      result = described_class.call(params: { event_date_id: event_date.id })
      expect(result).to run_successfully
    end.to change(Topic, :count).by(1)

    successor = Topic.where(title:).where.not(id: post.topic_id).sole
    successor_event = successor.first_post.reload.event

    # September's last Monday is its fourth Monday, but the original
    # August anchor was the fifth Monday (meaning the last Monday).
    expect(successor_event.original_starts_at).to eq_time(Time.utc(2026, 9, 28, 12))
    expect(successor_event.recurrence_anchor_starts_at).to eq_time(starts_at)

    occurrences =
      successor_event.recurring_occurrences(
        after: successor_event.original_starts_at + 1.second,
        limit: 3,
      )

    expect(occurrences.map { |occurrence| occurrence[:starts_at] }).to eq(
      [Time.utc(2026, 10, 26, 12), Time.utc(2026, 11, 30, 12), Time.utc(2026, 12, 28, 12)],
    )
  end
end
