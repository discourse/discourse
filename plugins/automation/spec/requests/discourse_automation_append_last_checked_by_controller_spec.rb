# frozen_string_literal: true

describe DiscourseAutomation::AppendLastCheckedByController do
  before { SiteSetting.discourse_automation_enabled = true }

  describe "#post_checked" do
    fab!(:post)
    fab!(:topic) { post.topic }
    fab!(:reply_author) { Fabricate(:user, refresh_auto_groups: true) }
    fab!(:reply) { Fabricate(:post, topic:, user: reply_author) }

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

    it "does not let reply authors mark topic documents as checked" do
      sign_in(reply_author)

      expect { put "/append-last-checked-by/#{reply.id}.json" }.not_to change {
        topic.reload.custom_fields.slice(
          DiscourseAutomation::TOPIC_LAST_CHECKED_BY,
          DiscourseAutomation::TOPIC_LAST_CHECKED_AT,
        )
      }

      expect(response.status).to eq(403)
      expect(response.parsed_body).to have_key("errors")
    end

    it "returns error if user can not edit the post" do
      sign_in(Fabricate(:user))

      put "/append-last-checked-by/#{post.id}.json"
      expect(response.status).to eq(403)
    end
  end
end
