# frozen_string_literal: true

RSpec.describe UpcomingChanges::NotifyPromotions do
  describe ".call" do
    subject(:result) { described_class.call }

    fab!(:admin)
    fab!(:admin_2, :admin)

    let(:enable_upload_debug_mode_status) { :stable }
    let(:show_user_menu_avatars_status) { :beta }

    before do
      SiteSetting.promote_upcoming_changes_on_status = :stable
      SiteSetting.stubs(:upcoming_change_site_settings).returns(
        %i[enable_upload_debug_mode show_user_menu_avatars],
      )

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

    context "when there is an error when trying to process a change" do
      before do
        StaffActionLogger
          .any_instance
          .stubs(:log_upcoming_change_toggle)
          .raises(StandardError, "test error")
      end

      it { is_expected.to fail_a_step(:process_changes) }

      it "returns the errors" do
        expect(result[:errors]).to match(
          [
            {
              setting_name: :enable_upload_debug_mode,
              error: "test error",
              backtrace: a_kind_of(Array),
            },
          ],
        )
      end
    end

    context "when everything is ok" do
      it { is_expected.to run_successfully }

      it "returns the successes" do
        expect(result[:successes]).to eq([:enable_upload_debug_mode])
      end

      it "returns the errors" do
        expect(result[:errors]).to be_empty
      end

      it "logs the change context in the staff action log" do
        expect { result }.to change {
          UserHistory.where(
            action: UserHistory.actions[:upcoming_change_toggled],
            subject: "enable_upload_debug_mode",
          ).count
        }.by(1)

        expect(UserHistory.last.context).to eq(
          I18n.t(
            "staff_action_logs.upcoming_changes.log_promoted",
            change_status: UpcomingChanges.change_status(:enable_upload_debug_mode).to_s.titleize,
            base_path: Discourse.base_path,
          ),
        )
      end

      it "notifies admins about the upcoming change" do
        expect { result }.to change {
          Notification
            .where(
              notification_type: Notification.types[:upcoming_change_automatically_promoted],
              user_id: [admin.id, admin_2.id],
            )
            .where("data::text LIKE ?", "%enable_upload_debug_mode%")
            .count
        }.by(2)

        notification = Notification.where("data::text LIKE ?", "%enable_upload_debug_mode%").last
        expect(notification.data).to eq(
          {
            upcoming_change_name: :enable_upload_debug_mode,
            upcoming_change_humanized_name: "Enable upload debug mode",
          }.to_json,
        )
      end

      it "creates an admins_notified_automatic_promotion event" do
        expect { result }.to change {
          UpcomingChangeEvent.where(
            event_type: :admins_notified_automatic_promotion,
            upcoming_change_name: :enable_upload_debug_mode,
          ).count
        }.by(1)
      end

      it "triggers DiscourseEvent for the promoted setting" do
        events = DiscourseEvent.track_events { result }
        event =
          events.find do |e|
            e[:event_name] == :upcoming_change_enabled &&
              e[:params].first == :enable_upload_debug_mode
          end

        expect(event).to be_present
        expect(event[:params]).to eq([:enable_upload_debug_mode])
      end

      context "when multiple settings meet promotion criteria" do
        let(:show_user_menu_avatars_status) { :stable }

        it "processes all eligible settings" do
          expect { result }.to change {
            Notification.where(
              notification_type: Notification.types[:upcoming_change_automatically_promoted],
              user_id: [admin.id, admin_2.id],
            ).count
          }.by(4)
        end

        it "creates events for all promoted settings" do
          expect { result }.to change {
            UpcomingChangeEvent.where(
              event_type: :admins_notified_automatic_promotion,
              upcoming_change_name: %i[enable_upload_debug_mode show_user_menu_avatars],
            ).count
          }.by(2)
        end

        it "triggers DiscourseEvent for all promoted settings" do
          events = DiscourseEvent.track_events { result }
          promoted_events = events.select { |e| e[:event_name] == :upcoming_change_enabled }

          expect(promoted_events.length).to eq(2)
          expect(promoted_events.map { |e| e[:params].first }).to contain_exactly(
            :enable_upload_debug_mode,
            :show_user_menu_avatars,
          )
        end
      end

      context "when there are no upcoming changes" do
        before { SiteSetting.stubs(:upcoming_change_site_settings).returns([]) }

        it "does not create any notifications" do
          expect { result }.not_to change { Notification.count }
        end

        it "does not trigger any events" do
          events = DiscourseEvent.track_events { result }
          expect(events.select { |e| e[:event_name] == :upcoming_change_enabled }).to be_empty
        end
      end

      context "when settings do not meet promotion status" do
        let(:enable_upload_debug_mode_status) { :beta }
        let(:show_user_menu_avatars_status) { :alpha }

        it "does not create any notifications" do
          expect { result }.not_to change { Notification.count }
        end

        it "does not trigger any events" do
          events = DiscourseEvent.track_events { result }
          expect(events.select { |e| e[:event_name] == :upcoming_change_enabled }).to be_empty
        end
      end

      context "when settings are already notified about promotion" do
        before do
          UpcomingChangeEvent.create!(
            event_type: :admins_notified_automatic_promotion,
            upcoming_change_name: :enable_upload_debug_mode,
            acting_user: Discourse.system_user,
          )
        end

        it "does not notify admins again for the already-notified setting" do
          expect { result }.not_to change {
            Notification
              .where(notification_type: Notification.types[:upcoming_change_automatically_promoted])
              .where("data::text LIKE ?", "%enable_upload_debug_mode%")
              .count
          }
        end

        it "does not trigger event for the already-notified setting" do
          events = DiscourseEvent.track_events { result }
          expect(
            events.select do |e|
              e[:event_name] == :upcoming_change_enabled &&
                e[:params].first == :enable_upload_debug_mode
            end,
          ).to be_empty
        end
      end

      context "when settings are opted out" do
        before { SiteSetting.enable_upload_debug_mode = false }

        it "does not notify admins for opted-out settings" do
          expect { result }.not_to change {
            Notification
              .where(notification_type: Notification.types[:upcoming_change_automatically_promoted])
              .where("data::text LIKE ?", "%enable_upload_debug_mode%")
              .count
          }
        end

        it "does not trigger event for opted-out settings" do
          events = DiscourseEvent.track_events { result }
          expect(
            events.select do |e|
              e[:event_name] == :upcoming_change_enabled &&
                e[:params].first == :enable_upload_debug_mode
            end,
          ).to be_empty
        end
      end
    end
  end
end
