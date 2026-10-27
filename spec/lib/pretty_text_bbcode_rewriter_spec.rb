# frozen_string_literal: true

require "pretty_text"

RSpec.describe PrettyText do
  describe ".rewrite_bbcode_tag" do
    def rewrite(raw, changes)
      candidate = described_class.scan_bbcode_tags(raw, tag: "excerpt").sole

      described_class.rewrite_bbcode_tag(
        raw,
        tag: "excerpt",
        candidate: candidate.fetch("index"),
        expected_opening: candidate.fetch("opening"),
        changes: changes,
      )
    end

    it "preserves untouched attributes, Unicode, and line endings" do
      raw = "😃\r\n[excerpt title='Old' flag]\r\nText\r\n[/excerpt]"

      expect(rewrite(raw, "title" => "Room ] A")).to eq(
        "😃\r\n[excerpt flag title=\"Room ] A\"]\r\nText\r\n[/excerpt]",
      )
    end

    it "preserves an unquoted apostrophe when removing another attribute" do
      raw = "[excerpt name=John's recurrence=every_week]Body[/excerpt]"

      expect(rewrite(raw, "recurrence" => nil)).to eq("[excerpt name=John's]Body[/excerpt]")
    end

    it "serializes false and zero without dropping their values" do
      raw = "[excerpt option=old]Body[/excerpt]"

      expect(rewrite(raw, "option" => false, "count" => 0)).to eq(
        "[excerpt option=false count=0]Body[/excerpt]",
      )
    end

    it "removes duplicate attributes" do
      raw = "[excerpt name=old name=new flag]Body[/excerpt]"

      expect(rewrite(raw, "name" => nil)).to eq("[excerpt flag]Body[/excerpt]")
    end

    it "preserves untouched duplicate attributes" do
      raw = "[excerpt name=old name=new state=old]Body[/excerpt]"

      expect(rewrite(raw, "state" => "new")).to eq(
        "[excerpt name=old name=new state=new]Body[/excerpt]",
      )
    end

    it "removes every renderer-equivalent spelling of an attribute" do
      raw =
        '[excerpt name="Recurrence Until" Recurrence=every_week recurrenceUntil=2027-04-05 recurrence-until=2027-04-06]Body[/excerpt]'

      expect(rewrite(raw, "recurrence" => nil, "recurrence-until" => nil)).to eq(
        '[excerpt name="Recurrence Until"]Body[/excerpt]',
      )
    end

    it "replaces all mixed-case aliases without leaving duplicate rendered attributes" do
      raw = "[excerpt Start=old start=stale End=before]Body[/excerpt]"

      expect(rewrite(raw, "start" => "new", "end" => "after")).to eq(
        "[excerpt start=new end=after]Body[/excerpt]",
      )
    end

    it "rejects a stale opening tag snapshot" do
      raw = "[excerpt title=old]Body[/excerpt]"
      candidate = described_class.scan_bbcode_tags(raw, tag: "excerpt").sole

      expect do
        described_class.rewrite_bbcode_tag(
          raw.sub("title=old", "title=new"),
          tag: "excerpt",
          candidate: candidate.fetch("index"),
          expected_opening: candidate.fetch("opening"),
          changes: {
            "title" => "replacement",
          },
        )
      end.to raise_error(MiniRacer::RuntimeError, /BBCode target changed/)
    end

    it "rejects attribute values that cannot be serialized losslessly" do
      raw = "[excerpt name=old]Body[/excerpt]"
      value = %q{"'«»“”‘’„‚‹› ]}

      expect { rewrite(raw, "name" => value) }.to raise_error(
        MiniRacer::RuntimeError,
        /cannot be serialized without changing their values/,
      )
    end

    it "explicitly rejects unsupported default attribute rewrites" do
      raw = "[excerpt=old]Body[/excerpt]"

      expect { rewrite(raw, "_default" => "new") }.to raise_error(
        MiniRacer::RuntimeError,
        /default BBCode attributes is not supported/,
      )
    end
  end
end
