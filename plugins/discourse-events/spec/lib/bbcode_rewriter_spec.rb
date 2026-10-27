# frozen_string_literal: true

require "bbcode_rewriter"

RSpec.describe BbcodeRewriter do
  before do
    SiteSetting.discourse_events_enabled = true
    SiteSetting.discourse_post_event_enabled = true
  end

  def build_rewriter(raw)
    described_class.new(raw, tag: "event", selector: "div.discourse-post-event")
  end

  let(:event_tag) do
    '[event name="Year End Party" start="2027-03-29 12:00" end="2027-03-29 13:00" timezone="UTC" recurrence="every_week"]'
  end

  it "rewrites a live event but preserves a fenced-code decoy and surrounding Unicode" do
    raw =
      "Before 😃\r\n\r\n```\r\n[event start=2000-01-01 recurrence=every_week]\r\n[/event]\r\n```\r\n\r\n#{event_tag}\r\nMeeting notes.\r\n[/event]\r\n"

    archived =
      build_rewriter(raw).rewrite(
        "start" => "2027-03-29 12:00",
        "end" => "2027-03-29 13:00",
        "recurrence" => nil,
      )

    expect(archived).to start_with(
      "Before 😃\r\n\r\n```\r\n[event start=2000-01-01 recurrence=every_week]",
    )
    expect(archived).to include('name="Year End Party"')
    expect(archived).not_to include('recurrence="every_week"')
    expect(archived).to end_with("Meeting notes.\r\n[/event]\r\n")
  end

  it "returns separate rewrites from the same original snapshot" do
    rewriter = build_rewriter("#{event_tag}\nNotes.\n[/event]")
    archive = rewriter.rewrite("recurrence" => nil)
    successor = rewriter.rewrite("start" => "2027-04-05 12:00", "end" => "2027-04-05 13:00")

    expect(archive).not_to include("recurrence=")
    expect(successor).to match(/\brecurrence=(?:"every_week"|every_week)(?=[\s\]])/)
    expect(successor).to include('start="2027-04-05 12:00"')
    expect(successor).to include('end="2027-04-05 13:00"')
  end

  it "rejects an event found only in a code fence" do
    raw = "```\n#{event_tag}\n[/event]\n```"
    expect { build_rewriter(raw).rewrite("recurrence" => nil) }.to raise_error(
      described_class::TargetNotFound,
    )
  end

  it "rejects more than one live rendered event" do
    raw = "#{event_tag}\nOne.\n[/event]\n\n#{event_tag}\nTwo.\n[/event]"
    expect { build_rewriter(raw).rewrite("recurrence" => nil) }.to raise_error(
      described_class::AmbiguousTarget,
    )
  end

  it "rejects newline attribute values rather than corrupting a tag" do
    raw = "#{event_tag}\nNotes.\n[/event]"
    expect { build_rewriter(raw).rewrite("name" => "a\nb") }.to raise_error(
      described_class::InvalidRewrite,
    )
  end
end
