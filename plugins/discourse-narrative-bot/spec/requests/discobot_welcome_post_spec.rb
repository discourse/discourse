# frozen_string_literal: true

RSpec.describe "Discobot welcome post" do
  let(:user) { Fabricate(:user) }

  before { SiteSetting.discourse_narrative_bot_enabled = true }

  context "when discourse_narrative_bot_welcome_post_delay is 0" do
    it "should not delay the welcome post" do
      user
      expect { sign_in(user) }.to_not change { Jobs::NarrativeInit.jobs.count }
    end
  end

  context "when discourse_narrative_bot_welcome_post_delay is greater than 0" do
    before { SiteSetting.discourse_narrative_bot_welcome_post_delay = 5 }

    context "when user logs in normally" do
      it "should delay the welcome post until user logs in" do
        expect { sign_in(user) }.to change { Jobs::NarrativeInit.jobs.count }.by(1)
        expect(Jobs::NarrativeInit.jobs.first["args"].first["user_id"]).to eq(user.id)
      end
    end

    context "when user redeems an invite" do
      let!(:invite) do
        Fabricate(:invite, invited_by: Fabricate(:admin), email: "testing@gmail.com")
      end

      it "should delay the welcome post until the user logs in" do
        expect do
          put "/invites/show/#{invite.invite_key}.json",
              params: {
                username: "somename",
                name: "testing",
                password: "verystrongpassword",
                email_token: invite.email_token,
              }
        end.to change { User.count }.by(1)

        expect(Jobs::NarrativeInit.jobs.first["args"].first["user_id"]).to eq(User.last.id)
      end
    end
  end

  context "when user is staged" do
    let(:staged_user) { Fabricate(:user, staged: true) }

    before { SiteSetting.discourse_narrative_bot_welcome_post_type = "welcome_message" }

    it "should not send welcome message" do
      expect { staged_user }.to_not change { Jobs::SendDefaultWelcomeMessage.jobs.count }
    end
  end
end
