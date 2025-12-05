# frozen_string_literal: true

RSpec.describe DiscourseZendeskPlugin::PostExtension do
  let(:user) { Fabricate(:user) }
  let(:category) { Fabricate(:category) }
  let(:topic) { Fabricate(:topic, user: user, category: category) }

  before do
    SiteSetting.zendesk_enabled = true
    SiteSetting.zendesk_jobs_email = "test@example.com"
    SiteSetting.zendesk_jobs_api_token = "token123"
  end

  describe "#generate_zendesk_ticket" do
    context "when zendesk is disabled" do
      before { SiteSetting.zendesk_enabled = false }

      it "does not enqueue job" do
        expect { Fabricate(:post, topic: topic, user: user) }.not_to change(
          Jobs::ZendeskJob.jobs,
          :size,
        )
      end
    end

    context "when zendesk is enabled" do
      context "when category is NOT in autogenerate list" do
        before { SiteSetting.zendesk_autogenerate_all_categories = false }

        context "when topic does NOT have existing zendesk ticket" do
          it "does not enqueue job" do
            expect { Fabricate(:post, topic: topic, user: user) }.not_to change(
              Jobs::ZendeskJob.jobs,
              :size,
            )
          end
        end

        context "when topic has existing zendesk ticket" do
          before do
            topic.custom_fields[DiscourseZendeskPlugin::ZENDESK_ID_FIELD] = "12345"
            topic.save_custom_fields
          end

          it "enqueues job" do
            expect { Fabricate(:post, topic: topic, user: user) }.to change(
              Jobs::ZendeskJob.jobs,
              :size,
            ).by(1)
          end
        end
      end

      context "when category is in autogenerate list" do
        before { SiteSetting.zendesk_autogenerate_all_categories = true }

        context "when topic does NOT have existing zendesk ticket" do
          it "enqueues job" do
            expect { Fabricate(:post, topic: topic, user: user) }.to change(
              Jobs::ZendeskJob.jobs,
              :size,
            ).by(1)
          end
        end

        context "when topic has existing zendesk ticket" do
          before do
            topic.custom_fields[DiscourseZendeskPlugin::ZENDESK_ID_FIELD] = "12345"
            topic.save_custom_fields
          end

          it "enqueues job" do
            expect { Fabricate(:post, topic: topic, user: user) }.to change(
              Jobs::ZendeskJob.jobs,
              :size,
            ).by(1)
          end
        end
      end

      context "when using specific categories setting" do
        before do
          SiteSetting.zendesk_autogenerate_all_categories = false
          SiteSetting.zendesk_autogenerate_categories = category.id.to_s
        end

        it "enqueues job for category in list" do
          expect { Fabricate(:post, topic: topic, user: user) }.to change(
            Jobs::ZendeskJob.jobs,
            :size,
          ).by(1)
        end

        it "does not enqueue job for category not in list" do
          other_category = Fabricate(:category)
          other_topic = Fabricate(:topic, user: user, category: other_category)

          expect { Fabricate(:post, topic: other_topic, user: user) }.not_to change(
            Jobs::ZendeskJob.jobs,
            :size,
          )
        end
      end
    end
  end
end
