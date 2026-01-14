# frozen_string_literal: true

RSpec.describe ProblemCheck::UpcomingChangeStableOptedOut do
  subject(:check) { described_class.new(target) }

  describe ".call" do
    let(:target) { "enable_upload_debug_mode" }

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
        it do
          expect(check).to have_a_problem.with_priority("low").with_target(
            "enable_upload_debug_mode",
          )
        end
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

        it do
          expect(check).to have_a_problem.with_priority("low").with_target(
            "enable_upload_debug_mode",
          )
        end
      end
    end
  end
end
