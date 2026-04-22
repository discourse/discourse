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

      it "returns a not found error" do
        get "/admin/problem_checks.json"
        expect(response.status).to eq(404)
      end
    end
  end

  describe "#ignore" do
    context "when tracker exists" do
      before { sign_in(admin) }

      it "ignores the problem" do
        put "/admin/problem_checks/#{problem_check_tracker.id}/ignore.json"
        expect(response.status).to eq(204)
      end
    end

    context "when tracker does not exist" do
      before { sign_in(admin) }

      it "returns a not found error" do
        put "/admin/problem_checks/1337/ignore.json"
        expect(response.status).to eq(404)
      end
    end

    context "when not logged in as admin" do
      before { sign_in(user) }

      it "returns a not found error" do
        put "/admin/problem_checks/#{problem_check_tracker.id}/ignore.json"
        expect(response.status).to eq(404)
      end
    end
  end

  describe "#watch" do
    context "when tracker exists" do
      before { sign_in(admin) }

      it "watches the problem" do
        put "/admin/problem_checks/#{problem_check_tracker.id}/watch.json"
        expect(response.status).to eq(204)
      end
    end

    context "when tracker does not exist" do
      before { sign_in(admin) }

      it "returns a not found error" do
        put "/admin/problem_checks/1337/watch.json"
        expect(response.status).to eq(404)
      end
    end

    context "when not logged in as admin" do
      before { sign_in(user) }

      it "returns a not found error" do
        put "/admin/problem_checks/#{problem_check_tracker.id}/watch.json"
        expect(response.status).to eq(404)
      end
    end
  end
end
