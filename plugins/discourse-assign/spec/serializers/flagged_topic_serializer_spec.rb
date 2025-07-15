# frozen_string_literal: true

require "rails_helper"
require_relative "../support/assign_allowed_group"

describe FlaggedTopicSerializer do
  fab!(:user)
  let(:guardian) { Guardian.new(user) }

  include_context "with group that is allowed to assign"

  before do
    SiteSetting.assign_enabled = true
    add_to_assign_allowed_group(user)
  end

  context "when there are no assignments" do
    let(:topic) { Fabricate(:topic) }

    it "does not include assignment attributes" do
      json = FlaggedTopicSerializer.new(topic, scope: guardian).as_json

      expect(json[:flagged_topic]).to_not have_key(:assigned_to_user)
      expect(json[:flagged_topic]).to_not have_key(:assigned_to_group)
    end
  end

  context "when there is a user assignment" do
    let(:topic) do
      topic =
        Fabricate(:topic, topic_allowed_users: [Fabricate.build(:topic_allowed_user, user: user)])

      topic.posts << Fabricate(:post)

      Assigner.new(topic, user).assign(user)
      topic
    end

    it "includes the assigned_to_user attribute" do
      json = FlaggedTopicSerializer.new(topic, scope: guardian).as_json

      expect(json[:flagged_topic][:assigned_to_user]).to match(
        { username: user.username, name: user.name, avatar_template: /letter_avatar_proxy.*/ },
      )
      expect(json[:flagged_topic]).to_not have_key(:assigned_to_group)
    end
  end

  context "when there is a group assignment" do
    let(:topic) do
      topic =
        Fabricate(
          :topic,
          topic_allowed_groups: [
            Fabricate.build(:topic_allowed_group, group: assign_allowed_group),
          ],
        )

      topic.posts << Fabricate(:post)

      Assigner.new(topic, user).assign(assign_allowed_group)
      topic
    end

    it "includes the assigned_to_group attribute" do
      json = FlaggedTopicSerializer.new(topic, scope: guardian).as_json

      expect(json[:flagged_topic][:assigned_to_group]).to match(
        {
          name: assign_allowed_group.name,
          flair_bg_color: assign_allowed_group.flair_bg_color,
          flair_color: assign_allowed_group.flair_color,
          flair_icon: assign_allowed_group.flair_icon,
          flair_upload_id: assign_allowed_group.flair_upload_id,
        },
      )
      expect(json[:flagged_topic]).to_not have_key(:assigned_to_user)
    end
  end
end
