# frozen_string_literal: true

describe DiscourseAutomation::AdminAutomationsController do
  before { SiteSetting.discourse_automation_enabled = true }

  describe "#trigger" do
    fab!(:automation)

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
              resource: "automations_trigger",
              action: "post",
              allowed_parameters: {
                "id" => [automation.id.to_s],
              },
            )
          end
        end

        it "works" do
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
  end
end
