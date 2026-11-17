# frozen_string_literal: true

describe DiscourseAutomation::AdminAutomationsController do
  before { SiteSetting.discourse_automation_enabled = true }

  describe "#trigger" do
    fab!(:automation) { Fabricate(:automation, trigger: DiscourseAutomation::Triggers::RECURRING) }

    describe "access" do
      context "when user is not logged in" do
        before { sign_out }

        it "raises a 404" do
          post "/automations/#{automation.id}/trigger.json"
          expect(response.status).to eq(404)
        end
      end

      context "when user is logged in" do
        context "when user is admin" do
          before do
            Jobs.run_immediately!
            sign_in(Fabricate(:admin))
          end

          it "triggers the automation" do
            list = capture_contexts { post "/automations/#{automation.id}/trigger.json" }

            expect(list.length).to eq(1)
            expect(list[0]["kind"]).to eq("api_call")
          end
        end

        context "when user is moderator" do
          before { sign_in(Fabricate(:moderator)) }

          it "raises a 404" do
            post "/automations/#{automation.id}/trigger.json"
            expect(response.status).to eq(404)
          end
        end

        context "when user is regular" do
          before { sign_in(Fabricate(:user)) }

          it "raises a 404" do
            post "/automations/#{automation.id}/trigger.json"
            expect(response.status).to eq(404)
          end
        end
      end

      context "when using a user api key" do
        before { sign_out }

        let(:admin) { Fabricate(:admin) }
        let(:api_key) { Fabricate(:api_key, user: admin) }
        let(:restricted_api_key) do
          Fabricate(:api_key, user: admin).tap do |key|
            ApiKeyScope.create!(
              api_key_id: key.id,
              resource: "automation",
              action: "trigger_automation",
              allowed_parameters: {
                "id" => [automation.id.to_s],
              },
            )
          end
        end

        it "enqueues the automation trigger with an admin API key" do
          post "/automations/#{automation.id}/trigger.json",
               params: {
                 context: {
                   foo: :bar,
                 },
               },
               headers: {
                 HTTP_API_KEY: api_key.key,
               }

          expect(response.status).to eq(200)
          expect(Jobs::DiscourseAutomation::Trigger.jobs.size).to eq(1)
        end

        it "enforces the automation ID from the path" do
          other_automation = Fabricate(:automation)

          post "/automations/#{automation.id}/trigger.json",
               params: {
                 context: {
                   foo: :bar,
                 },
               },
               headers: {
                 HTTP_API_KEY: restricted_api_key.key,
               }
          expect(response.status).to eq(200)

          post "/automations/#{other_automation.id}/trigger.json",
               params: {
                 id: automation.id,
                 context: {
                   foo: :bar,
                 },
               },
               headers: {
                 HTTP_API_KEY: restricted_api_key.key,
               }
          expect(response.status).to eq(404)
        end
      end
    end

    describe "params as context" do
      fab!(:admin)
      fab!(:automation) { Fabricate(:automation, trigger: "api_call") }

      before do
        Jobs.run_immediately!
        sign_in(admin)
      end

      it "passes the params" do
        list =
          capture_contexts do
            post "/automations/#{automation.id}/trigger.json", params: { foo: "1", bar: "2" }
          end

        expect(list.length).to eq(1)

        first = list.first

        expect(first["foo"]).to eq("1")
        expect(first["bar"]).to eq("2")
        expect(response.status).to eq(200)
      end
    end

    describe "with a granular API key" do
      fab!(:admin)
      fab!(:private_message_recipient, :user)
      fab!(:private_post) do
        Fabricate(
          :post,
          topic: Fabricate(:private_message_topic, recipient: private_message_recipient),
          raw: "private post excerpt",
        )
      end
      fab!(:like) do
        Fabricate(
          :post_action,
          post: private_post,
          post_action_type_id: PostActionType.types[:like],
        )
      end
      fab!(:automation) do
        Fabricate(
          :automation,
          script: DiscourseAutomation::Scripts::EMAIL_ON_FLAGGED_POST,
          trigger: DiscourseAutomation::Triggers::POST_FLAG_CREATED,
        )
      end
      let(:api_key) do
        Fabricate(
          :api_key,
          user: admin,
          api_key_scopes: [
            Fabricate.build(:api_key_scope, resource: "automation", action: "trigger_automation"),
          ],
        )
      end

      before do
        Jobs.run_later!
        SiteSetting.disable_emails = "no"
        automation.upsert_field!(
          "email_template",
          "message",
          {
            value:
              I18n.t("discourse_automation.scriptables.email_on_flagged_post.default_template"),
          },
        )
        automation.upsert_field!("recipients", "users", { value: ["attacker@example.com"] })
      end

      it "blocks a forged like from an event-only automation" do
        get "/posts/#{private_post.id}.json",
            headers: {
              HTTP_API_KEY: api_key.key,
              HTTP_API_USERNAME: admin.username,
            }

        expect(response.status).to eq(403)
        expect(response.parsed_body["errors"]).to be_present
        expect(like.post_action_type_id).to eq(PostActionType.types[:like])

        trigger_jobs_count = Jobs::DiscourseAutomation::Trigger.jobs.size
        email_jobs_count = Jobs::DiscourseAutomation::SendFlagEmail.jobs.size
        deliveries_count = ActionMailer::Base.deliveries.size

        post "/automations/#{automation.id}/trigger.json",
             params: {
               post_action_id: like.id,
             },
             headers: {
               HTTP_API_KEY: api_key.key,
               HTTP_API_USERNAME: admin.username,
             }

        expect(response.status).to eq(403)
        expect(response.parsed_body["errors"]).to be_present
        expect(Jobs::DiscourseAutomation::Trigger.jobs.size).to eq(trigger_jobs_count)
        expect(Jobs::DiscourseAutomation::SendFlagEmail.jobs.size).to eq(email_jobs_count)
        expect(ActionMailer::Base.deliveries.size).to eq(deliveries_count)
      end
    end
  end
end
