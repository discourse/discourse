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

      it "logs the selected plan_categories option with readable details" do
        post "/admin/onboarding/events.json",
             params: {
               event: "step_completed",
               step: "start_posting",
               topic_option: "plan_categories",
             }

        expect(response.status).to eq(204)
        log = UserHistory.last
        expect(log.subject).to eq("start_posting")
        expect(log.new_value).to eq("plan_categories")
        expect(log.details).to eq(
          I18n.t(
            "staff_action_logs.admin_onboarding_topic_option",
            option:
              I18n.t("js.admin_onboarding_banner.start_posting.icebreakers.plan_categories.title"),
            option_id: "plan_categories",
          ),
        )
      end

      it "logs the selected plan_invites option with readable details" do
        post "/admin/onboarding/events.json",
             params: {
               event: "step_completed",
               step: "start_posting",
               topic_option: "plan_invites",
             }

        expect(response.status).to eq(204)
        log = UserHistory.last
        expect(log.subject).to eq("start_posting")
        expect(log.new_value).to eq("plan_invites")
        expect(log.details).to eq(
          I18n.t(
            "staff_action_logs.admin_onboarding_topic_option",
            option:
              I18n.t("js.admin_onboarding_banner.start_posting.icebreakers.plan_invites.title"),
            option_id: "plan_invites",
          ),
        )
      end

      it "logs the selected introduce_yourself option with readable details" do
        post "/admin/onboarding/events.json",
             params: {
               event: "step_completed",
               step: "start_posting",
               topic_option: "introduce_yourself",
             }

        expect(response.status).to eq(204)
        log = UserHistory.last
        expect(log.subject).to eq("start_posting")
        expect(log.new_value).to eq("introduce_yourself")
        expect(log.details).to eq(
          I18n.t(
            "staff_action_logs.admin_onboarding_topic_option",
            option:
              I18n.t(
                "js.admin_onboarding_banner.start_posting.icebreakers.introduce_yourself.title",
              ),
            option_id: "introduce_yourself",
          ),
        )
      end

      it "logs the selected write_your_own option with readable details" do
        post "/admin/onboarding/events.json",
             params: {
               event: "step_completed",
               step: "start_posting",
               topic_option: "write_your_own",
             }

        expect(response.status).to eq(204)
        log = UserHistory.last
        expect(log.subject).to eq("start_posting")
        expect(log.new_value).to eq("write_your_own")
        expect(log.details).to eq(
          I18n.t(
            "staff_action_logs.admin_onboarding_topic_option",
            option:
              I18n.t("js.admin_onboarding_banner.start_posting.icebreakers.write_your_own.title"),
            option_id: "write_your_own",
          ),
        )
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
