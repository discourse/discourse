# frozen_string_literal: true

RSpec.describe Admin::ProblemChecksController do
  fab!(:admin)
  fab!(:user)
  fab!(:problem_check_tracker) do
    Fabricate(
      :problem_check_tracker,
      identifier: "rails_env",
      target: ProblemCheck::NO_TARGET,
      blips: 0,
      last_run_at: 1.hour.ago,
      last_success_at: 1.hour.ago,
    )
  end

  describe "#index" do
    context "when logged in as admin" do
      before { sign_in(admin) }

      it "returns problem check trackers" do
        get "/admin/problem_checks.json"

        expect(response.status).to eq(200)

        trackers = response.parsed_body

        expect(trackers.map { |t| t["identifier"] }).to contain_exactly("rails_env")
      end
    end

    context "when not logged in as admin" do
      before { sign_in(user) }

      it "denies access" do
        get "/admin/problem_checks.json"
        expect(response.status).to eq(404)
      end
    end
  end
end
