# frozen_string_literal: true

require_relative "../discourse_automation_helper"

describe DiscourseAutomation::AppendLastCheckedByController do
  before { SiteSetting.discourse_automation_enabled = true }

  describe "#post_checked" do
    fab!(:post) { Fabricate(:post) }
    fab!(:topic) { post.topic }

    it "updates the topic custom fields" do
      freeze_time
      admin = Fabricate(:admin)
      sign_in(admin)

      put "/append-last-checked-by/#{post.id}.json"
      expect(response.status).to eq(200)
      expect(topic.custom_fields[DiscourseAutomation::TOPIC_LAST_CHECKED_BY]).to eq(admin.username)
      topic_last_checked_at =
        Time.parse(topic.custom_fields[DiscourseAutomation::TOPIC_LAST_CHECKED_AT])
      expect(topic_last_checked_at).to be_within_one_second_of(Time.zone.now)
    end

    it "returns error if user can not edit the post" do
      sign_in(Fabricate(:user))

      put "/append-last-checked-by/#{post.id}.json"
      expect(response.status).to eq(403)
    end
  end
end
