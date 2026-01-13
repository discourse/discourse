# frozen_string_literal: true

RSpec.describe "Track upcoming changes initializer" do
  context "when enable_upcoming_changes is disabled" do
    before do
      SiteSetting.enable_upcoming_changes = false
      SiteSetting.promote_upcoming_changes_on_status = :stable
    end

    it "does nothing" do
      SiteSetting.expects(:upcoming_change_site_settings).never
      UpcomingChanges::TrackingInitializer.call
    end
  end

  context "when enable_upcoming_changes is enabled" do
    before do
      SiteSetting.enable_upcoming_changes = true
      SiteSetting.upcoming_change_verbose_logging = true
      SiteSetting.promote_upcoming_changes_on_status = :stable
    end

    context "when there are upcoming changes to track" do
      fab!(:admin)

      before do
        mock_upcoming_change_metadata(
          {
            enable_upload_debug_mode: {
              impact: "other,developers",
              status: :beta,
              impact_type: "other",
              impact_role: "developers",
            },
            enable_user_tips: {
              impact: "feature,all_members",
              status: :alpha,
              impact_type: "feature",
              impact_role: "all_members",
            },
          },
        )
      end

      context "when changes are newly added" do
        before do
          UpcomingChangeEvent.where(
            upcoming_change_name: %i[enable_upload_debug_mode enable_user_tips],
          ).delete_all
        end

        it "logs added changes" do
          track_log_messages do |logger|
            UpcomingChanges::TrackingInitializer.call
            expect(logger.infos.join("\n")).to include(
              "added upcoming change 'enable_upload_debug_mode'",
            )
            expect(logger.infos.join("\n")).to include("added upcoming change 'enable_user_tips'")
          end
        end
      end

      context "when admins are notified about an available change" do
        before do
          UpcomingChangeEvent.where(
            upcoming_change_name: %i[enable_upload_debug_mode enable_user_tips],
          ).delete_all
        end

        it "logs that admins were notified" do
          track_log_messages do |logger|
            UpcomingChanges::TrackingInitializer.call
            expect(logger.infos.join("\n")).to include(
              "notified site admins about added upcoming change 'enable_upload_debug_mode'",
            )
          end
        end

        it "does not log notification for changes that do not meet status threshold" do
          track_log_messages do |logger|
            UpcomingChanges::TrackingInitializer.call
            expect(logger.infos.join("\n")).not_to include(
              "notified site admins about added upcoming change 'enable_user_tips'",
            )
          end
        end
      end

      context "when changes are removed" do
        before do
          UpcomingChangeEvent.create!(event_type: :added, upcoming_change_name: :old_removed_change)
        end

        after { UpcomingChangeEvent.where(upcoming_change_name: :old_removed_change).delete_all }

        it "logs removed changes" do
          track_log_messages do |logger|
            UpcomingChanges::TrackingInitializer.call
            expect(logger.infos.join("\n")).to include(
              "removed upcoming change 'old_removed_change'",
            )
          end
        end
      end

      context "when status changes for an existing change" do
        before do
          UpcomingChangeEvent.create!(
            event_type: :added,
            upcoming_change_name: :enable_upload_debug_mode,
          )
          UpcomingChangeEvent.create!(
            event_type: :status_changed,
            upcoming_change_name: :enable_upload_debug_mode,
            event_data: {
              "previous_value" => nil,
              "new_value" => "alpha",
            },
          )
          UpcomingChangeEvent.create!(
            event_type: :admins_notified_available_change,
            upcoming_change_name: :enable_upload_debug_mode,
          )
        end

        it "logs status changes" do
          track_log_messages do |logger|
            UpcomingChanges::TrackingInitializer.call
            expect(logger.infos.join("\n")).to include(
              "status changed for upcoming change 'enable_upload_debug_mode' from alpha to beta",
            )
          end
        end
      end
    end

    context "when the UpcomingChanges::Track service has an unexpected failure" do
      before do
        mock_upcoming_change_metadata(
          {
            enable_upload_debug_mode: {
              impact: "other,developers",
              status: :stable,
              impact_type: "other",
              impact_role: "developers",
            },
          },
        )
      end

      it "logs the error" do
        failing_track =
          Class.new(UpcomingChanges::Track) do
            def run!
              context.fail(error: "Simulated failure")
              raise Service::Base::Failure.new(context)
            end
          end

        stub_const(UpcomingChanges, "Track", failing_track) do
          track_log_messages do |logger|
            UpcomingChanges::TrackingInitializer.call
            expect(logger.errors.join("\n")).to include(
              "Failed to track upcoming changes', an unexpected error occurred.",
            )
          end
        end
      end
    end
  end
end
