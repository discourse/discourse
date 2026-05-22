# frozen_string_literal: true

RSpec.describe Admin::CommandCenterController do
  fab!(:admin)
  fab!(:user) { Fabricate(:user, username: "markvanlan", trust_level: 1) }

  describe "#users" do
    before { sign_in(admin) }

    it "finds users by username and email" do
      user.primary_email.update!(email: "mark@example.com")

      get "/admin/command-center/users.json", params: { term: "mark@example" }

      expect(response.status).to eq(200)
      expect(response.parsed_body["users"]).to contain_exactly(
        include("id" => user.id, "username" => "markvanlan"),
      )
    end

    it "escapes wildcard characters in the search term" do
      user.primary_email.update!(email: "mark@example.com")

      get "/admin/command-center/users.json", params: { term: "m%" }

      expect(response.status).to eq(200)
      expect(response.parsed_body["users"]).to eq([])
    end
  end

  describe "#preview" do
    before { sign_in(admin) }

    it "returns a validated suspension preview without suspending the user" do
      post "/admin/command-center/preview.json",
           params: {
             command: "Suspend markvanlan for 7 days because repeated spam",
           }

      expect(response.status).to eq(200)
      expect(response.parsed_body).to include(
        "intent" => "suspend_user",
        "parser" => include("source" => "deterministic"),
        "user" => include("id" => user.id, "username" => "markvanlan"),
        "suspension" =>
          include(
            "duration" => "7 days",
            "reason" => "repeated spam",
            "message" => "Your account has been temporarily suspended. Reason: repeated spam",
          ),
      )
      expect(user.reload).not_to be_suspended
    end

    it "does not prefill a user-facing message when suspension reasons are hidden" do
      SiteSetting.hide_suspension_reasons = true

      post "/admin/command-center/preview.json",
           params: {
             command: "Suspend markvanlan because internal spam signal",
           }

      expect(response.status).to eq(200)
      expect(response.parsed_body["suspension"]).to include(
        "reason" => "internal spam signal",
        "message" => nil,
      )
    end

    it "rejects unsupported commands" do
      post "/admin/command-center/preview.json", params: { command: "Delete markvanlan" }

      expect(response.status).to eq(422)
      expect(response.parsed_body["message"]).to eq(
        "I could not identify a supported admin action.",
      )
    end

    it "returns candidates when the user cannot be resolved" do
      post "/admin/command-center/preview.json", params: { command: "Suspend mark" }

      expect(response.status).to eq(404)
      expect(response.parsed_body).to include(
        "message" => "I could not find a user named mark.",
        "candidates" => [include("id" => user.id, "username" => "markvanlan")],
      )
    end

    it "does not allow moderators to preview suspending staff" do
      moderator = Fabricate(:moderator)
      sign_in(moderator)

      post "/admin/command-center/preview.json", params: { command: "Suspend #{admin.username}" }

      expect(response.status).to eq(403)
    end
  end
end
