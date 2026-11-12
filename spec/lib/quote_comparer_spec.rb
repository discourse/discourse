# frozen_string_literal: true

require "quote_comparer"

RSpec.describe QuoteComparer do
  describe "#missing?" do
    fab!(:post) { Fabricate(:post, raw: "This has **text** we _are_ matching") }

    it "returns true for missing topic and post" do
      expect(QuoteComparer.new(nil, nil, "test", user: post.user)).to be_missing
    end

    it "returns true for missing topic" do
      expect(QuoteComparer.new(nil, post.post_number, "test", user: post.user)).to be_missing
    end

    it "returns true for missing post" do
      expect(QuoteComparer.new(post.topic_id, nil, "test", user: post.user)).to be_missing
    end

    it "returns false for only missing text" do
      expect(
        QuoteComparer.new(post.topic_id, post.post_number, nil, user: post.user),
      ).to_not be_missing
    end

    it "returns false for no missing topic and post" do
      expect(
        QuoteComparer.new(post.topic_id, post.post_number, "test", user: post.user),
      ).to_not be_missing
    end
  end

  describe "#modified?" do
    fab!(:post) { Fabricate(:post, raw: "This has **text** we _are_ matching") }

    def qc(text)
      QuoteComparer.new(post.topic_id, post.post_number, text, user: post.user)
    end

    it "returns true for nil text" do
      expect(qc(nil)).to be_modified
    end

    it "returns true for empty text" do
      expect(qc("")).to be_modified
    end

    it "returns true for modified text" do
      expect(qc("text is modified")).to be_modified
    end

    it "return false when the text matches exactly" do
      expect(qc("This has text we are matching")).not_to be_modified
    end

    it "return false when there's a substring" do
      expect(qc("text we are")).not_to be_modified
    end

    it "return false when there's extra space" do
      expect(qc("\n\ntext   we are \t")).not_to be_modified
    end
  end

  describe "visibility" do
    fab!(:user)
    fab!(:post) { Fabricate(:post, raw: "This has **text** we _are_ matching") }

    it "treats the post as missing when no user is given" do
      comparer = QuoteComparer.new(post.topic_id, post.post_number, "text is modified")
      expect(comparer).to be_missing
      expect(comparer).not_to be_modified
    end

    it "treats a private message the user cannot see as missing" do
      pm = Fabricate(:private_message_post, raw: "secret text only some users can read")

      comparer = QuoteComparer.new(pm.topic_id, pm.post_number, "secret text", user:)
      expect(comparer).to be_missing
      expect(comparer).not_to be_modified
    end

    it "compares a private message the user can see" do
      pm = Fabricate(:private_message_post, raw: "secret text only some users can read")

      comparer = QuoteComparer.new(pm.topic_id, pm.post_number, "secret text", user: pm.user)
      expect(comparer).not_to be_missing
      expect(comparer).not_to be_modified

      comparer =
        QuoteComparer.new(
          pm.topic_id,
          pm.post_number,
          "wrong text",
          user: pm.topic.allowed_users.first,
        )
      expect(comparer).not_to be_missing
      expect(comparer).to be_modified
    end

    it "treats a post in a restricted category the user cannot see as missing" do
      group = Fabricate(:group)
      member = Fabricate(:user, group_ids: [group.id])
      category = Fabricate(:private_category, group:)
      hidden =
        Fabricate(
          :post,
          raw: "hidden category text",
          user: member,
          topic: Fabricate(:topic, category:),
        )

      comparer = QuoteComparer.new(hidden.topic_id, hidden.post_number, "wrong text", user:)
      expect(comparer).to be_missing
      expect(comparer).not_to be_modified

      comparer = QuoteComparer.new(hidden.topic_id, hidden.post_number, "wrong text", user: member)
      expect(comparer).not_to be_missing
      expect(comparer).to be_modified
    end
  end
end
