# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::PostButton::V1 do
  fab!(:group)
  fab!(:user)
  fab!(:post)

  describe "#valid?" do
    it "returns true when the post is present" do
      trigger = described_class.new(post)
      expect(trigger).to be_valid
    end

    it "returns false when the post is nil" do
      trigger = described_class.new(nil)
      expect(trigger).not_to be_valid
    end
  end

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

    it "returns an empty array when the parameter is missing" do
      expect(described_class.normalized_group_ids({})).to eq([])
    end
  end

  describe ".available_to?" do
    it "returns false for an anonymous user" do
      expect(described_class.available_to?(nil, "group_ids" => [group.id])).to eq(false)
    end

    it "returns false when no groups are configured" do
      expect(described_class.available_to?(user, "group_ids" => [])).to eq(false)
    end

    it "returns false when the user is in none of the configured groups" do
      expect(described_class.available_to?(user, "group_ids" => [group.id])).to eq(false)
    end

    it "returns true when the user is a member of a configured group" do
      group.add(user)

      expect(described_class.available_to?(user, "group_ids" => [group.id])).to eq(true)
    end

    it "returns true for any logged-in user when the logged-in users group is configured" do
      expect(
        described_class.available_to?(user, "group_ids" => [Group::AUTO_GROUPS[:logged_in_users]]),
      ).to eq(true)
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
