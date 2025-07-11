# frozen_string_literal: true

require "rails_helper"

describe "TopicExtensions" do
  before { freeze_time }

  fab!(:user_1) { Fabricate(:user, admin: true) }
  fab!(:topic_1) { Fabricate(:topic, user: user_1) }

  context "when an enabled category is set on the topic" do
    fab!(:category_1) { Fabricate(:category) }

    before { SiteSetting.zendesk_autogenerate_categories = "#{category_1.id}" }

    it "queues a sync job" do
      expect_enqueued_with(
        job: :zendesk_job,
        args: {
          topic_id: topic_1.id,
        },
        at: Time.zone.now + 5.seconds,
      ) do
        topic_1.category = category_1
        topic_1.save!
      end
    end

    context "when the category is removed" do
      before do
        topic_1.category = category_1
        topic_1.save!
      end

      it "queues a sync job" do
        expect_enqueued_with(
          job: :zendesk_job,
          args: {
            topic_id: topic_1.id,
          },
          at: Time.zone.now + 5.seconds,
        ) do
          topic_1.category = nil
          topic_1.save!
        end
      end
    end
  end
end
