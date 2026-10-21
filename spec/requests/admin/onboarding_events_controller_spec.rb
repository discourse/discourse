# frozen_string_literal: true

RSpec.describe Admin::OnboardingEventsController do
  fab!(:admin)
  fab!(:user)

  describe "#create" do
    context "when signed in as an admin" do
      before { sign_in(admin) }

      it "logs a staff action for a completed step" do
        post "/admin/onboarding/events.json",
             params: {
               event: "step_completed",
               step: "select_theme",
             }

        expect(response.status).to eq(204)

        log = UserHistory.last
        expect(log.action).to eq(UserHistory.actions[:admin_onboarding_step_completed])
        expect(log.acting_user_id).to eq(admin.id)
        expect(log.subject).to eq("select_theme")
      end

      UserHistory::ADMIN_ONBOARDING_TOPIC_OPTIONS.each do |option|
        it "logs the selected #{option} option with readable details" do
          post "/admin/onboarding/events.json",
               params: {
                 event: "step_completed",
                 step: "start_posting",
                 topic_option: option,
               }

          expect(response.status).to eq(204)
          log = UserHistory.last
          expect(log.subject).to eq("start_posting")
          expect(log.new_value).to eq(option)
          expect(log.details).to eq(
            I18n.t(
              "staff_action_logs.admin_onboarding_topic_option",
              option:
                I18n.t("js.admin_onboarding_banner.start_posting.icebreakers.#{option}.title"),
              option_id: option,
            ),
          )
        end
      end

      it "still logs posting completed outside the suggested options" do
        post "/admin/onboarding/events.json",
             params: {
               event: "step_completed",
               step: "start_posting",
             }

        expect(response.status).to eq(204)
        expect(UserHistory.last.new_value).to be_nil
        expect(UserHistory.last.details).to be_nil
      end

      it "rejects an unknown topic option without logging" do
        expect {
          post "/admin/onboarding/events.json",
               params: {
                 event: "step_completed",
                 step: "start_posting",
                 topic_option: "unknown",
               }
        }.not_to change { UserHistory.count }

        expect(response.status).to eq(400)
      end

      it "rejects a topic option for another step without logging" do
        expect {
          post "/admin/onboarding/events.json",
               params: {
                 event: "step_completed",
                 step: "select_theme",
                 topic_option: "plan_categories",
               }
        }.not_to change { UserHistory.count }

        expect(response.status).to eq(400)
      end

      it "logs a staff action when onboarding is completed" do
        post "/admin/onboarding/events.json", params: { event: "completed" }

        expect(response.status).to eq(204)
        expect(UserHistory.last.action).to eq(UserHistory.actions[:admin_onboarding_completed])
      end

      it "logs a staff action when onboarding is dismissed" do
        post "/admin/onboarding/events.json", params: { event: "dismissed" }

        expect(response.status).to eq(204)
        expect(UserHistory.last.action).to eq(UserHistory.actions[:admin_onboarding_dismissed])
      end

      it "rejects an unknown event without logging" do
        expect {
          post "/admin/onboarding/events.json", params: { event: "something_else" }
        }.not_to change { UserHistory.count }

        expect(response.status).to eq(400)
      end

      it "rejects an unknown step without logging" do
        expect {
          post "/admin/onboarding/events.json",
               params: {
                 event: "step_completed",
                 step: "not_a_step",
               }
        }.not_to change { UserHistory.count }

        expect(response.status).to eq(400)
      end
    end

    it "denies access to a regular user" do
      sign_in(user)

      expect {
        post "/admin/onboarding/events.json", params: { event: "completed" }
      }.not_to change { UserHistory.count }

      expect(response.status).to eq(404)
    end

    it "denies access to an anonymous user" do
      expect {
        post "/admin/onboarding/events.json", params: { event: "completed" }
      }.not_to change { UserHistory.count }

      expect(response.status).to eq(404)
    end
  end
end
