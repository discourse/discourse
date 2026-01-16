# frozen_string_literal: true

RSpec.describe UpcomingChanges::Track do
  let(:enable_upload_debug_mode_status) { :experimental }
  let(:show_user_menu_avatars_status) { :beta }

  before do
    mock_upcoming_change_metadata(
      {
        enable_upload_debug_mode: {
          impact: "other,developers",
          status: enable_upload_debug_mode_status,
          impact_type: "other",
          impact_role: "developers",
        },
        show_user_menu_avatars: {
          impact: "feature,all_members",
          status: show_user_menu_avatars_status,
          impact_type: "feature",
          impact_role: "all_members",
        },
      },
    )
  end

  # There will be real upcoming changes in site_settings.yml that
  # affect these tests, so we scope down to only the ones we
  # are mocking.
  def scoped_events
    UpcomingChangeEvent.where(
      upcoming_change_name: %i[enable_upload_debug_mode show_user_menu_avatars],
    )
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies, options:) }

    let(:params) { {} }
    let(:guardian) { Discourse.system_user.guardian }
    let(:dependencies) { { guardian: } }
    let(:options) { {} }

    fab!(:admin_1, :admin)
    fab!(:admin_2, :admin)

    context "when everything's ok" do
      it { is_expected.to run_successfully }
    end

    describe "#track_added_changes" do
      before { scoped_events.where(event_type: :added).delete_all }

      it "creates UpcomingChangeEvent entries for new upcoming changes" do
        expect { result }.to change { scoped_events.where(event_type: :added).count }.by(2)
      end

      it "returns the added changes in the result context" do
        expect(result[:added_changes]).to include(
          :enable_upload_debug_mode,
          :show_user_menu_avatars,
        )
      end

      context "when there are previously added changes" do
        before do
          UpcomingChangeEvent.create!(
            event_type: :added,
            upcoming_change_name: :enable_upload_debug_mode,
          )
        end

        it "does not re-record previously added changes" do
          expect { result }.not_to change {
            scoped_events.where(
              event_type: :added,
              upcoming_change_name: :enable_upload_debug_mode,
            ).count
          }
        end

        it "only records the new changes" do
          expect { result }.to change {
            scoped_events.where(
              event_type: :added,
              upcoming_change_name: :show_user_menu_avatars,
            ).count
          }.by(1)
        end

        it "returns only the newly added changes for the scoped settings" do
          expect(result[:added_changes]).to include(:show_user_menu_avatars)
          expect(result[:added_changes]).not_to include(:enable_upload_debug_mode)
        end
      end

      context "when the change status meets promotion_status - 1" do
        let(:show_user_menu_avatars_status) { :beta }

        before { SiteSetting.promote_upcoming_changes_on_status = "stable" }

        it "notifies all admins" do
          expect { result }.to change {
            Notification
              .where(notification_type: Notification.types[:upcoming_change_available])
              .where("data::text LIKE ?", "%show_user_menu_avatars%")
              .count
          }.by(2)
        end

        it "creates a notification with correct data for each admin" do
          result
          notification =
            Notification
              .where(
                notification_type: Notification.types[:upcoming_change_available],
                user_id: admin_1.id,
              )
              .where("data::text LIKE ?", "%show_user_menu_avatars%")
              .first

          data = JSON.parse(notification.data)
          expect(data["upcoming_change_name"]).to eq("show_user_menu_avatars")
          expect(data["upcoming_change_humanized_name"]).to eq(
            SiteSetting.humanized_name(:show_user_menu_avatars),
          )
        end

        it "creates an admins_notified_available_change event" do
          expect { result }.to change {
            scoped_events.where(
              event_type: :admins_notified_available_change,
              upcoming_change_name: :show_user_menu_avatars,
            ).count
          }.by(1)
        end

        it "includes the change in notified_admins_for_added_changes" do
          expect(result[:notified_admins_for_added_changes]).to include(:show_user_menu_avatars)
        end

        it "creates a UserHistory entry for the upcoming change" do
          expect { result }.to change {
            UserHistory.where(
              action: UserHistory.actions[:upcoming_change_available],
              subject: "show_user_menu_avatars",
            ).count
          }.by(1)
        end
      end

      context "when the change status does not meet promotion_status - 1" do
        let(:enable_upload_debug_mode_status) { :alpha }
        let(:show_user_menu_avatars_status) { :alpha }

        before { SiteSetting.promote_upcoming_changes_on_status = "stable" }

        it "does not notify admins for the scoped alpha changes" do
          result
          expect(
            Notification
              .where(notification_type: Notification.types[:upcoming_change_available])
              .where("data::text LIKE ?", "%enable_upload_debug_mode%")
              .count,
          ).to eq(0)
          expect(
            Notification
              .where(notification_type: Notification.types[:upcoming_change_available])
              .where("data::text LIKE ?", "%show_user_menu_avatars%")
              .count,
          ).to eq(0)
        end

        it "does not create an admins_notified_available_change event for the scoped settings" do
          expect { result }.not_to change {
            scoped_events.where(
              event_type: :admins_notified_available_change,
              upcoming_change_name: :enable_upload_debug_mode,
            ).count
          }
        end

        it "does not include the scoped changes in notified_admins_for_added_changes" do
          notified = result[:notified_admins_for_added_changes]
          expect(notified).not_to include(:enable_upload_debug_mode)
          expect(notified).not_to include(:show_user_menu_avatars)
        end

        it "does not create a UserHistory entry for the scoped changes" do
          expect { result }.not_to change {
            UserHistory.where(
              action: UserHistory.actions[:upcoming_change_available],
              subject: %w[enable_upload_debug_mode show_user_menu_avatars],
            ).count
          }
        end
      end

      context "when change is added at exactly promotion status threshold" do
        let(:show_user_menu_avatars_status) { :stable }

        before { SiteSetting.promote_upcoming_changes_on_status = "stable" }

        it "does not notify admins (Promote service will handle it)" do
          result
          expect(
            Notification
              .where(notification_type: Notification.types[:upcoming_change_available])
              .where("data::text LIKE ?", "%show_user_menu_avatars%")
              .count,
          ).to eq(0)
        end

        it "does not create an admins_notified_available_change event" do
          expect { result }.not_to change {
            scoped_events.where(
              event_type: :admins_notified_available_change,
              upcoming_change_name: :show_user_menu_avatars,
            ).count
          }
        end

        it "does not include the change in notified_admins_for_added_changes" do
          expect(result[:notified_admins_for_added_changes]).not_to include(:show_user_menu_avatars)
        end
      end
    end

    describe "#track_removed_changes" do
      before do
        UpcomingChangeEvent.create!(event_type: :added, upcoming_change_name: :old_removed_change)
        scoped_events.where(event_type: :removed).delete_all
      end

      it "creates a removed event for changes no longer in site settings" do
        expect { result }.to change {
          UpcomingChangeEvent.where(
            event_type: :removed,
            upcoming_change_name: :old_removed_change,
          ).count
        }.by(1)
      end

      it "returns the removed changes in the result context" do
        expect(result[:removed_changes]).to include(:old_removed_change)
      end

      context "when there are previously removed changes" do
        before do
          UpcomingChangeEvent.create!(
            event_type: :removed,
            upcoming_change_name: :old_removed_change,
          )
        end

        it "does not re-record previously removed changes" do
          expect { result }.not_to change {
            UpcomingChangeEvent.where(
              event_type: :removed,
              upcoming_change_name: :old_removed_change,
            ).count
          }
        end

        it "does not include previously removed changes in result" do
          expect(result[:removed_changes]).not_to include(:old_removed_change)
        end
      end

      context "when a change is still in the site settings" do
        it "does not create a removed event for current changes" do
          expect { result }.not_to change {
            scoped_events.where(
              event_type: :removed,
              upcoming_change_name: :enable_upload_debug_mode,
            ).count
          }
        end
      end
    end

    describe "#track_status_changes" do
      before do
        scoped_events.where(event_type: :status_changed).delete_all
        scoped_events.where(event_type: :added).delete_all
        UpcomingChangeEvent.create!(
          event_type: :added,
          upcoming_change_name: :enable_upload_debug_mode,
        )
        UpcomingChangeEvent.create!(
          event_type: :added,
          upcoming_change_name: :show_user_menu_avatars,
        )
      end

      context "when there are no previous status changes" do
        it "creates a status_changed event for the current status" do
          expect { result }.to change { scoped_events.where(event_type: :status_changed).count }.by(
            2,
          )
        end

        it "sets previous_value to N/A in the event data" do
          result
          event =
            scoped_events.find_by(
              event_type: :status_changed,
              upcoming_change_name: :enable_upload_debug_mode,
            )
          parsed_data = event.event_data
          expect(parsed_data["previous_value"]).to be_nil
        end

        it "sets new_value to the current status in the event data" do
          result
          event =
            scoped_events.find_by(
              event_type: :status_changed,
              upcoming_change_name: :enable_upload_debug_mode,
            )
          parsed_data = event.event_data
          expect(parsed_data["new_value"]).to eq("experimental")
        end

        it "returns N/A as previous_value in the result context" do
          expect(result[:status_changes][:enable_upload_debug_mode]).to eq(
            { previous_value: "N/A", new_value: :experimental },
          )
        end
      end

      context "when there are added changes in the same run" do
        before { scoped_events.where(event_type: :added).delete_all }

        it "creates a status_changed event for newly added changes" do
          expect { result }.to change {
            scoped_events.where(
              event_type: :status_changed,
              upcoming_change_name: :enable_upload_debug_mode,
            ).count
          }.by(1)
        end

        it "does not send status change notifications for added changes" do
          result
          expect(result[:added_changes]).to include(:enable_upload_debug_mode)
          status_change_events =
            scoped_events.where(
              event_type: :status_changed,
              upcoming_change_name: :enable_upload_debug_mode,
            )
          expect(status_change_events.count).to eq(1)
        end
      end

      context "when there are removed changes in the same run" do
        before do
          UpcomingChangeEvent.create!(event_type: :added, upcoming_change_name: :old_removed_change)
          UpcomingChangeEvent.create!(
            event_type: :status_changed,
            upcoming_change_name: :old_removed_change,
            event_data: {
              "previous_value" => nil,
              "new_value" => "beta",
            },
          )
        end

        it "does not create a status change event for removed changes" do
          expect { result }.not_to change {
            UpcomingChangeEvent.where(
              event_type: :status_changed,
              upcoming_change_name: :old_removed_change,
            ).count
          }
        end
      end

      context "when the status has changed from a previous value" do
        let(:show_user_menu_avatars_status) { :stable }

        before do
          UpcomingChangeEvent.create!(
            event_type: :status_changed,
            upcoming_change_name: :show_user_menu_avatars,
            event_data: {
              "previous_value" => nil,
              "new_value" => "beta",
            },
          )
          UpcomingChangeEvent.create!(
            event_type: :status_changed,
            upcoming_change_name: :enable_upload_debug_mode,
            event_data: {
              "previous_value" => nil,
              "new_value" => "experimental",
            },
          )
          UpcomingChangeEvent.create!(
            event_type: :admins_notified_available_change,
            upcoming_change_name: :show_user_menu_avatars,
          )
        end

        it "creates a status_changed event with correct data" do
          expect { result }.to change {
            scoped_events.where(
              event_type: :status_changed,
              upcoming_change_name: :show_user_menu_avatars,
            ).count
          }.by(1)
        end

        it "records the previous and new status values" do
          result
          event =
            scoped_events
              .where(event_type: :status_changed, upcoming_change_name: :show_user_menu_avatars)
              .order(:created_at)
              .last
          parsed_data = event.event_data
          expect(parsed_data["previous_value"]).to eq("beta")
          expect(parsed_data["new_value"]).to eq("stable")
        end

        it "returns the status change in the result context" do
          expect(result[:status_changes][:show_user_menu_avatars]).to eq(
            { previous_value: "beta", new_value: :stable },
          )
        end
      end

      context "when status has not changed" do
        let(:show_user_menu_avatars_status) { :beta }

        before do
          UpcomingChangeEvent.create!(
            event_type: :status_changed,
            upcoming_change_name: :show_user_menu_avatars,
            event_data: {
              "previous_value" => nil,
              "new_value" => "beta",
            },
          )
          UpcomingChangeEvent.create!(
            event_type: :status_changed,
            upcoming_change_name: :enable_upload_debug_mode,
            event_data: {
              "previous_value" => nil,
              "new_value" => "experimental",
            },
          )
        end

        it "does not create a new status_changed event" do
          expect { result }.not_to change { scoped_events.where(event_type: :status_changed).count }
        end
      end

      context "when an added change did not meet promotion_status - 1 initially" do
        let(:show_user_menu_avatars_status) { :beta }

        before do
          SiteSetting.promote_upcoming_changes_on_status = "stable"
          UpcomingChangeEvent.create!(
            event_type: :status_changed,
            upcoming_change_name: :show_user_menu_avatars,
            event_data: {
              "previous_value" => nil,
              "new_value" => "alpha",
            },
          )
          UpcomingChangeEvent.create!(
            event_type: :status_changed,
            upcoming_change_name: :enable_upload_debug_mode,
            event_data: {
              "previous_value" => nil,
              "new_value" => "experimental",
            },
          )
        end

        it "notifies all admins when status now meets threshold" do
          expect { result }.to change {
            Notification
              .where(
                notification_type: Notification.types[:upcoming_change_available],
                user_id: [admin_1.id, admin_2.id],
              )
              .where("data::text LIKE ?", "%show_user_menu_avatars%")
              .count
          }.by(2)
        end

        it "creates an admins_notified_available_change event" do
          expect { result }.to change {
            scoped_events.where(
              event_type: :admins_notified_available_change,
              upcoming_change_name: :show_user_menu_avatars,
            ).count
          }.by(1)
        end

        it "includes the change in notified_admins_for_added_changes" do
          expect(result[:notified_admins_for_added_changes]).to include(:show_user_menu_avatars)
        end

        it "creates a UserHistory entry for the upcoming change" do
          expect { result }.to change {
            UserHistory.where(
              action: UserHistory.actions[:upcoming_change_available],
              subject: "show_user_menu_avatars",
            ).count
          }.by(1)
        end

        context "when admins were already notified" do
          before do
            UpcomingChangeEvent.create!(
              event_type: :admins_notified_available_change,
              upcoming_change_name: :show_user_menu_avatars,
            )
          end

          it "does not notify admins again" do
            expect { result }.not_to change {
              Notification
                .where(notification_type: Notification.types[:upcoming_change_available])
                .where("data::text LIKE ?", "%show_user_menu_avatars%")
                .count
            }
          end

          it "does not create another admins_notified_available_change event" do
            expect { result }.not_to change {
              scoped_events.where(
                event_type: :admins_notified_available_change,
                upcoming_change_name: :show_user_menu_avatars,
              ).count
            }
          end

          it "does not create another UserHistory entry" do
            expect { result }.not_to change {
              UserHistory.where(
                action: UserHistory.actions[:upcoming_change_available],
                subject: "show_user_menu_avatars",
              ).count
            }
          end
        end
      end

      context "when status change brings change to exactly promotion status threshold" do
        let(:show_user_menu_avatars_status) { :stable }

        before do
          SiteSetting.promote_upcoming_changes_on_status = "stable"
          UpcomingChangeEvent.create!(
            event_type: :status_changed,
            upcoming_change_name: :show_user_menu_avatars,
            event_data: {
              "previous_value" => nil,
              "new_value" => "beta",
            },
          )
          UpcomingChangeEvent.create!(
            event_type: :status_changed,
            upcoming_change_name: :enable_upload_debug_mode,
            event_data: {
              "previous_value" => nil,
              "new_value" => "experimental",
            },
          )
        end

        it "does not notify admins (Promote service will handle it)" do
          result
          expect(
            Notification
              .where(notification_type: Notification.types[:upcoming_change_available])
              .where("data::text LIKE ?", "%show_user_menu_avatars%")
              .count,
          ).to eq(0)
        end

        it "does not create an admins_notified_available_change event" do
          expect { result }.not_to change {
            scoped_events.where(
              event_type: :admins_notified_available_change,
              upcoming_change_name: :show_user_menu_avatars,
            ).count
          }
        end

        it "does not include the change in notified_admins_for_added_changes" do
          expect(result[:notified_admins_for_added_changes]).not_to include(:show_user_menu_avatars)
        end
      end
    end
  end
end
