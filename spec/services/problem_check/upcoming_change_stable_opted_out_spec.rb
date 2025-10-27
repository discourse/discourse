# frozen_string_literal: true

RSpec.describe ProblemCheck::UpcomingChangeStableOptedOut do
  subject(:check) { described_class.new }

  describe ".call" do
    before do
      @original_upcoming_changes_metadata = SiteSetting.upcoming_change_metadata.dup

      # We do this because upcoming changes are ephemeral in site settings,
      # so we cannot rely on them for specs. Instead we can fake some metadata
      # for an existing stable setting.
      SiteSetting.instance_variable_set(
        :@upcoming_change_metadata,
        @original_upcoming_changes_metadata.merge(
          {
            enable_upload_debug_mode: {
              impact: "other,developers",
              status: :stable,
              impact_type: "feature",
              impact_role: "admins",
            },
          },
        ),
      )
    end

    after do
      SiteSetting.instance_variable_set(
        :@upcoming_change_metadata,
        @original_upcoming_changes_metadata,
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
          SiteSetting.instance_variable_set(
            :@upcoming_change_metadata,
            @original_upcoming_changes_metadata.merge(
              {
                enable_upload_debug_mode: {
                  impact: "other,developers",
                  status: :alpha,
                  impact_type: "feature",
                  impact_role: "admins",
                },
              },
            ),
          )
        end

        it { expect(check).to be_chill_about_it }
      end

      context "when upcoming change is permanent and not opted in" do
        before do
          SiteSetting.instance_variable_set(
            :@upcoming_change_metadata,
            @original_upcoming_changes_metadata.merge(
              {
                enable_upload_debug_mode: {
                  impact: "other,developers",
                  status: :permanent,
                  impact_type: "feature",
                  impact_role: "admins",
                },
              },
            ),
          )
        end

        it { expect(check).to have_a_problem }
      end
    end
  end
end
