# frozen_string_literal: true

require_relative "../discourse_automation_helper"

describe DiscourseAutomation::AdminDiscourseAutomationAutomationsController do
  before { SiteSetting.discourse_automation_enabled = true }

  describe "#trigger" do
    fab!(:automation) { Fabricate(:automation) }

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
          before { sign_in(Fabricate(:admin)) }

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
        end
      end
    end

    describe "params as context" do
      fab!(:admin) { Fabricate(:admin) }
      fab!(:automation) { Fabricate(:automation, trigger: "api_call") }

      before { sign_in(admin) }

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
