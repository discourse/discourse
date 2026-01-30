# frozen_string_literal: true

RSpec.describe Jobs::CheckUpcomingChanges do
  describe "#execute" do
    context "when enable_upcoming_changes is disabled" do
      before do
        SiteSetting.enable_upcoming_changes = false
        SiteSetting.upcoming_change_verbose_logging = true
      end

      it "does not log" do
        track_log_messages do |logger|
          described_class.new.execute({})
          expect(logger.infos).to be_empty
          expect(logger.errors).to be_empty
        end
      end
    end

    context "when enable_upcoming_changes is enabled" do
      fab!(:admin)

      before do
        SiteSetting.enable_upcoming_changes = true
        SiteSetting.upcoming_change_verbose_logging = true
        SiteSetting.promote_upcoming_changes_on_status = :stable
      end

      context "when there are no upcoming changes" do
        before { SiteSetting.stubs(:upcoming_change_site_settings).returns([]) }

        it "logs start message and that no changes are present" do
          track_log_messages do |logger|
            described_class.new.execute({})
            expect(logger.infos.join("\n")).to include(
              "Starting change tracker and promotion notifier for upcoming changes",
            )
            expect(logger.infos.join("\n")).to include("No upcoming changes present.")
          end
        end
      end

      context "when there are upcoming changes to track" do
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

        it "synchronizes execution using DistributedMutex" do
          DistributedMutex
            .expects(:synchronize)
            .with("check_upcoming_changes_default", validity: 10.minutes)
            .yields
          described_class.new.execute({})
        end

        context "when changes are newly added" do
          before do
            UpcomingChangeEvent.where(
              upcoming_change_name: %i[enable_upload_debug_mode enable_user_tips],
            ).delete_all
          end

          it "logs added changes" do
            track_log_messages do |logger|
              described_class.new.execute({})
              expect(logger.infos.join("\n")).to include(
                "Added upcoming change 'enable_upload_debug_mode'",
              )
              expect(logger.infos.join("\n")).to include("Added upcoming change 'enable_user_tips'")
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
              described_class.new.execute({})
              expect(logger.infos.join("\n")).to include(
                "Notified site admins about added upcoming change 'enable_upload_debug_mode'",
              )
            end
          end

          it "does not log notification for changes that do not meet status threshold" do
            track_log_messages do |logger|
              described_class.new.execute({})
              expect(logger.infos.join("\n")).not_to include(
                "Notified site admins about added upcoming change 'enable_user_tips'",
              )
            end
          end
        end

        context "when changes are removed" do
          before do
            UpcomingChangeEvent.create!(
              event_type: :added,
              upcoming_change_name: :old_removed_change,
            )
          end

          after { UpcomingChangeEvent.where(upcoming_change_name: :old_removed_change).delete_all }

          it "logs removed changes" do
            track_log_messages do |logger|
              described_class.new.execute({})
              expect(logger.infos.join("\n")).to include(
                "Removed upcoming change 'old_removed_change'",
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
              described_class.new.execute({})
              expect(logger.infos.join("\n")).to include(
                "Status changed for upcoming change 'enable_upload_debug_mode' from alpha to beta",
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
              described_class.new.execute({})
              expect(logger.errors.join("\n")).to include(
                "Failed to track upcoming changes, an unexpected error occurred.",
              )
            end
          end
        end
      end

      context "when notifying promotions" do
        before do
          mock_upcoming_change_metadata(
            {
              enable_upload_debug_mode: {
                impact: "other,developers",
                status: :stable,
                impact_type: "other",
                impact_role: "developers",
              },
              enable_user_tips: {
                impact: "feature,all_members",
                status: :beta,
                impact_type: "feature",
                impact_role: "all_members",
              },
              show_user_menu_avatars: {
                impact: "feature,all_members",
                status: :permanent,
                impact_type: "feature",
                impact_role: "all_members",
              },
            },
          )
        end

        context "when the change meets promotion criteria" do
          before do
            UpcomingChangeEvent.create!(
              event_type: :added,
              upcoming_change_name: :enable_upload_debug_mode,
            )
            UpcomingChangeEvent.create!(
              event_type: :admins_notified_available_change,
              upcoming_change_name: :enable_upload_debug_mode,
            )
            UpcomingChangeEvent.where(
              upcoming_change_name: :enable_upload_debug_mode,
              event_type: :admins_notified_automatic_promotion,
            ).delete_all

            UpcomingChangeEvent.create!(
              event_type: :added,
              upcoming_change_name: :show_user_menu_avatars,
            )
            UpcomingChangeEvent.create!(
              event_type: :admins_notified_available_change,
              upcoming_change_name: :show_user_menu_avatars,
            )
            UpcomingChangeEvent.create!(
              event_type: :admins_notified_automatic_promotion,
              upcoming_change_name: :show_user_menu_avatars,
              acting_user: Discourse.system_user,
            )
          end

          it "logs promotion notification" do
            track_log_messages do |logger|
              described_class.new.execute({})
              expect(logger.infos.join("\n")).to include(
                "Notified site admins about promotion of 'enable_upload_debug_mode'",
              )
            end
          end
        end

        context "when the change does not meet promotion criteria" do
          before { SiteSetting.promote_upcoming_changes_on_status = :never }

          it "does not log promotion" do
            track_log_messages do |logger|
              described_class.new.execute({})
              expect(logger.infos.join("\n")).not_to include(
                "Notified site admins about promotion of 'enable_upload_debug_mode'",
              )
            end
          end

          it "logs the error" do
            track_log_messages do |logger|
              described_class.new.execute({})
              expect(logger.errors.join("\n")).to include(
                "Failed to notify about promotion of 'enable_upload_debug_mode': Setting enable_upload_debug_mode does not meet or exceed the promotion status",
              )
            end
          end
        end

        context "when notifying about permanent changes" do
          before do
            UpcomingChangeEvent.create!(
              event_type: :added,
              upcoming_change_name: :show_user_menu_avatars,
            )
            UpcomingChangeEvent.create!(
              event_type: :admins_notified_available_change,
              upcoming_change_name: :show_user_menu_avatars,
            )
          end

          it "logs promotion of permanent change" do
            track_log_messages do |logger|
              described_class.new.execute({})
              expect(logger.infos.join("\n")).to include(
                "Notified site admins about promotion of 'show_user_menu_avatars'",
              )
            end
          end
        end
      end
    end

    context "when upcoming_change_verbose_logging is disabled" do
      before do
        SiteSetting.enable_upcoming_changes = true
        SiteSetting.upcoming_change_verbose_logging = false
        SiteSetting.stubs(:upcoming_change_site_settings).returns([])
      end

      it "does not log" do
        track_log_messages do |logger|
          described_class.new.execute({})
          expect(logger.infos).to be_empty
        end
      end
    end
  end
end
