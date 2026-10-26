# frozen_string_literal: true

require "pretty_text"

RSpec.describe PrettyText do
  describe ".update_bbcode_attributes" do
    it "updates the first matching block while preserving other attributes and content" do
      raw =
        "Before\n\n[excerpt title=«Room ] title=old» state=old]\n**Content**\n[/excerpt]\n\n[excerpt]Later[/excerpt]"

      expect(described_class.update_bbcode_attributes(raw, "excerpt", { state: "new" })).to eq(
        raw.sub("state=old", "state=new"),
      )
    end

    it "adds quoted values using the shared serializer" do
      raw = "[excerpt]Content[/excerpt]"

      expect(described_class.update_bbcode_attributes(raw, "excerpt", { title: "Room ] A" })).to eq(
        '[excerpt title="Room ] A"]Content[/excerpt]',
      )
    end

    it "removes every occurrence of an attribute without changing quoted text" do
      raw = '[excerpt title=old label="title=old" title="new"]Content[/excerpt]'

      expect(described_class.update_bbcode_attributes(raw, "excerpt", { title: nil })).to eq(
        '[excerpt label="title=old"]Content[/excerpt]',
      )
    end

    it "preserves CRLF line endings and Unicode before a nested block" do
      raw = "Before 😃\r\n\r\n> [excerpt]\r\n> Content\r\n> [/excerpt]\r\n"

      expect(described_class.update_bbcode_attributes(raw, "excerpt", { title: "new" })).to eq(
        raw.sub("[excerpt]", "[excerpt title=new]"),
      )
    end

    it "ignores fenced and inline code" do
      raw = "```\n[excerpt]Example[/excerpt]\n```\n\n`[excerpt]Example[/excerpt]`"

      expect(described_class.update_bbcode_attributes(raw, "excerpt", { title: "new" })).to be_nil
    end

    it "ignores incomplete blocks" do
      expect(
        described_class.update_bbcode_attributes("[excerpt]Content", "excerpt", { title: "new" }),
      ).to be_nil
    end
  end

end
