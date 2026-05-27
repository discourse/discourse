# frozen_string_literal: true

RSpec.describe DiscourseZendeskPlugin::PostExtension do
  fab!(:user)
  fab!(:category)
  fab!(:topic) { Fabricate(:topic, user:, category:) }

  describe "#generate_zendesk_ticket" do
    context "when zendesk is disabled" do
      before { SiteSetting.zendesk_enabled = false }

      it "does not enqueue job" do
        expect { Fabricate(:post, topic:, user:) }.not_to change(Jobs::ZendeskJob.jobs, :size)
      end
    end

    context "when zendesk is enabled" do
      before do
        SiteSetting.zendesk_enabled = true
        SiteSetting.zendesk_jobs_email = "test@example.com"
        SiteSetting.zendesk_jobs_api_token = "token123"
      end

      context "when category is NOT in autogenerate list" do
        before { SiteSetting.zendesk_autogenerate_all_categories = false }

        it "does not enqueue job when topic has no zendesk ticket" do
          expect { Fabricate(:post, topic:, user:) }.not_to change(Jobs::ZendeskJob.jobs, :size)
        end

        it "enqueues job when topic has zendesk ticket" do
          TopicCustomField.create!(
            topic:,
            name: DiscourseZendeskPlugin::ZENDESK_ID_FIELD,
            value: "12345",
          )

          expect { Fabricate(:post, topic:, user:) }.to change(Jobs::ZendeskJob.jobs, :size).by(1)
        end
      end

      context "when category is in autogenerate list" do
        before { SiteSetting.zendesk_autogenerate_all_categories = true }

        it "enqueues job" do
          expect { Fabricate(:post, topic:, user:) }.to change(Jobs::ZendeskJob.jobs, :size).by(1)
        end
      end

      context "when using specific categories setting" do
        before do
          SiteSetting.zendesk_autogenerate_all_categories = false
          SiteSetting.zendesk_autogenerate_categories = category.id.to_s
        end

        it "enqueues job for category in list" do
          expect { Fabricate(:post, topic:, user:) }.to change(Jobs::ZendeskJob.jobs, :size).by(1)
        end

        it "does not enqueue job for category not in list" do
          other_topic = Fabricate(:topic, user:, category: Fabricate(:category))

          expect { Fabricate(:post, topic: other_topic, user:) }.not_to change(
            Jobs::ZendeskJob.jobs,
            :size,
          )
        end
      end
    end
  end
end
