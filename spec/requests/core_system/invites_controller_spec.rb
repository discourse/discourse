# frozen_string_literal: true

RSpec.describe InvitesController do
  describe "#create" do
    it "creates an admin link invite restricted to the submitted domain without sending email" do
      SiteSetting.enable_invite_modal_with_roles = true
      SiteSetting.enable_local_logins_via_code = false
      Jobs.run_immediately!
      admin = Fabricate(:admin)
      Fabricate(:invite, invited_by: admin, email: "placeholder@example.com")
      sign_in(admin)
      mail_count = ActionMailer::Base.deliveries.count

      expect do
        post "/invites.json", params: { is_admin: true, skip_email: true, domain: "example.com" }
      end.to change(Invite, :count).by(1)

      expect(response.status).to eq(200)
      expect(ActionMailer::Base.deliveries.count).to eq(mail_count)
      invite = Invite.find(response.parsed_body["id"])
      expect(response.parsed_body).to include(
        "link" => invite.link,
        "domain" => "example.com",
        "grants_admin" => true,
        "max_redemptions_allowed" => 1,
      )
      expect(invite.admin).to eq(true)
      expect(invite.email).to be_nil
      expect(invite.domain).to eq("example.com")
      expect(invite.max_redemptions_allowed).to eq(1)
      expect(invite.invited_by).to eq(admin)
    end
  end
end
