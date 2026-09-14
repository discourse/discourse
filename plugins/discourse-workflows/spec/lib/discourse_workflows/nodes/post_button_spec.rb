# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::PostButton::V1 do
  fab!(:post)

  describe "#output" do
    it "returns post and topic data" do
      output = described_class.new(post).output

      expect(output).to include(
        post: include(id: post.id, post_number: post.post_number, topic_id: post.topic_id),
        topic: include(id: post.topic.id, title: post.topic.title),
      )
    end
  end

  describe ".normalized_group_ids" do
    it "keeps only numeric ids" do
      expect(described_class.normalized_group_ids("group_ids" => [1, "2", "junk", nil, ""])).to eq(
        [1, 2],
      )
    end
  end

  describe ".available_to?" do
    it "returns false for an anonymous user" do
      expect(
        described_class.available_to?(nil, "group_ids" => [Group::AUTO_GROUPS[:logged_in_users]]),
      ).to eq(false)
    end
  end

  describe ".resolved_post_number" do
    it "returns nil when the post number is missing or blank" do
      [nil, "", " "].each do |post_number|
        expect(described_class.resolved_post_number("post_number" => post_number)).to be_nil
      end
    end

    it "returns an integer for positive numeric values" do
      [5, "5", " 5 "].each do |post_number|
        expect(described_class.resolved_post_number("post_number" => post_number)).to eq(5)
      end
    end

    it "returns the invalid sentinel for malformed and nonpositive values" do
      ["invalid", "1.5", 0, -1].each do |post_number|
        expect(described_class.resolved_post_number("post_number" => post_number)).to eq(
          described_class::INVALID_POST_NUMBER,
        )
      end
    end
  end

  describe ".matches_post_number?" do
    it "does not match any post when the post number is malformed" do
      expect(described_class.matches_post_number?(post, "post_number" => "invalid")).to eq(false)
    end
  end

  describe ".resolved_position" do
    it "defaults to last" do
      expect(described_class.resolved_position({})).to eq("last")
    end

    it "passes through preset positions" do
      expect(described_class.resolved_position("position" => "more_menu")).to eq("more_menu")
    end

    it "combines direction and anchor for relative positions" do
      expect(
        described_class.resolved_position(
          "position" => "relative",
          "position_direction" => "after",
          "position_anchor" => "like",
        ),
      ).to eq("after_like")
    end

    it "defaults relative positions to before reply" do
      expect(described_class.resolved_position("position" => "relative")).to eq("before_reply")
    end

    it "uses the custom key when the custom anchor is selected" do
      expect(
        described_class.resolved_position(
          "position" => "relative",
          "position_direction" => "after",
          "position_anchor" => "custom",
          "position_custom_key" => " custom-button ",
        ),
      ).to eq("after_custom-button")
    end

    it "falls back to last when the custom anchor has no key" do
      expect(
        described_class.resolved_position(
          "position" => "relative",
          "position_anchor" => "custom",
          "position_custom_key" => "",
        ),
      ).to eq("last")
    end
  end
end
