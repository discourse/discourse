# frozen_string_literal: true

RSpec.describe ProblemCheck::UpcomingChangeStableOptedOut do
  subject(:check) { described_class.new }

  describe ".call" do
    before do
      mock_upcoming_change_metadata(
        {
          enable_upload_debug_mode: {
            impact: "other,developers",
            status: :stable,
            impact_type: "feature",
            impact_role: "admins",
          },
        },
      )
    end

    context "when enable_upcoming_changes is disabled" do
      before { SiteSetting.enable_upcoming_changes = false }

      it { expect(check).to be_chill_about_it }
    end

    context "when enable_upcoming_changes is enabled" do
      before { SiteSetting.enable_upcoming_changes = true }

      context "when upcoming change is enabled (opted in)" do
        before { SiteSetting.enable_upload_debug_mode = true }

        it { expect(check).to be_chill_about_it }
      end

      context "when upcoming change is stable and not opted in" do
        it { expect(check).to have_a_problem }
      end

      context "when upcoming change is not yet stable and not opted in" do
        before do
          mock_upcoming_change_metadata(
            {
              enable_upload_debug_mode: {
                impact: "other,developers",
                status: :alpha,
                impact_type: "other",
                impact_role: "developers",
              },
            },
          )
        end

        it { expect(check).to be_chill_about_it }
      end

      context "when upcoming change is permanent and not opted in" do
        before do
          mock_upcoming_change_metadata(
            enable_upload_debug_mode: {
              impact: "other,developers",
              status: :permanent,
              impact_type: "other",
              impact_role: "developers",
            },
          )
        end

        it { expect(check).to have_a_problem }
      end
    end
  end
end
