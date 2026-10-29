# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::ComposerSnapshot do
  describe ".own_text" do
    it "removes quotes, quoted lines and HTML comments" do
      raw = <<~MD
        [quote="sam, post:1, topic:2"]Magic words[/quote]
        [quote]a [quote]b[/quote] food stand[/quote]
        > bad food
        <!-- Magic words -->
        Hello world
      MD

      expect(described_class.own_text(raw).squish).to eq("Hello world")
    end

    it "keeps unclosed quotes and comments as text" do
      expect(described_class.own_text("[quote]Magic words")).to eq("[quote]Magic words")
      expect(described_class.own_text("<!-- Magic words")).to eq("<!-- Magic words")
      expect(described_class.own_text("Magic words[/quote]")).to eq("Magic words[/quote]")
    end

    it "keeps text around an unclosed quote while removing the closed ones inside it" do
      expect(described_class.own_text("[quote]a [quote]b[/quote] Magic words")).to eq(
        "[quote]a  Magic words",
      )
    end

    it "handles deeply nested quotes in linear time" do
      depth = 2_000
      raw = "#{"[quote]" * depth}Magic words#{"[/quote]" * depth} Hello"

      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      text = described_class.own_text(raw)
      elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started

      expect(text).to eq(" Hello")
      expect(elapsed).to be < 0.5
    end
  end

  describe "#composable?" do
    fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
    fab!(:shared_drafts_category, :category)
    fab!(:shared_draft_topic) { Fabricate(:topic, category: shared_drafts_category) }

    before do
      SiteSetting.shared_drafts_category = shared_drafts_category.id
      SiteSetting.shared_drafts_allowed_groups = Group::AUTO_GROUPS[:staff]
      Fabricate(:shared_draft, topic: shared_draft_topic, category: Fabricate(:category))
    end

    def reply_to(topic)
      described_class.new(
        user:,
        action: described_class::REPLY,
        draft_key: "topic_#{topic.id}",
        raw: "Magic words",
        topic:,
      )
    end

    it "is false for a topic the user can post in but can't see" do
      expect(user.guardian.can_create_post_on_topic?(shared_draft_topic)).to eq(true)
      expect(reply_to(shared_draft_topic)).not_to be_composable
    end

    it "is true for a topic the user can see" do
      expect(reply_to(Fabricate(:topic))).to be_composable
    end
  end

  describe "#own_text" do
    fab!(:user)

    it "only looks at what a post can hold" do
      SiteSetting.max_post_length = 20
      snapshot =
        described_class.new(
          user:,
          action: "create_topic",
          draft_key: "new_topic",
          raw: "#{"a" * 20} Magic words",
        )

      expect(snapshot.raw.length).to eq(20)
      expect(snapshot.own_text).not_to include("Magic words")
    end
  end
end
