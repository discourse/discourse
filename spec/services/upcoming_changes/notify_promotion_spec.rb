# frozen_string_literal: true

RSpec.describe UpcomingChanges::NotifyPromotion do
  describe UpcomingChanges::NotifyPromotion::Contract, type: :model do
    it { is_expected.to validate_presence_of(:setting_name) }
    it { is_expected.to validate_presence_of(:admin_user_ids) }
  end

  describe ".call" do
    subject(:result) do
      described_class.call(
        params: {
          setting_name:,
          admin_user_ids:,
          changes_already_notified_about_promotion:,
        },
        guardian: Discourse.system_user.guardian,
      )
    end

    fab!(:admin)
    fab!(:admin_2, :admin)

    let(:setting_name) { :enable_upload_debug_mode }
    let(:admin_user_ids) { [admin.id, admin_2.id] }
    let(:changes_already_notified_about_promotion) { [] }
    let(:setting_status) { :stable }

    before do
      SiteSetting.promote_upcoming_changes_on_status = :stable
      mock_upcoming_change_metadata(
        enable_upload_debug_mode: {
          impact: "other,developers",
          status: setting_status,
          impact_type: "other",
          impact_role: "developers",
        },
      )
    end

    context "when data is invalid" do
      let(:setting_name) { nil }

      it { is_expected.to fail_a_contract }
    end

    context "when setting is not available" do
      let(:setting_name) { :nonexistent_setting }

      it { is_expected.to fail_a_policy(:setting_is_available) }
    end

    context "when setting does not meet or exceed promotion status" do
      let(:setting_status) { :beta }

      it { is_expected.to fail_a_policy(:meets_or_exceeds_status) }
    end

    context "when change has already been notified about promotion" do
      let(:changes_already_notified_about_promotion) { [:enable_upload_debug_mode] }

      it { is_expected.to fail_a_policy(:change_has_not_already_been_notified_about_promotion) }
    end

    context "when admin has manually opted out" do
      before { SiteSetting.enable_upload_debug_mode = false }

      it { is_expected.to fail_a_policy(:admin_has_not_manually_toggled) }
    end

    context "when admin has manually opted in" do
      before { SiteSetting.enable_upload_debug_mode = true }

      it { is_expected.to fail_a_policy(:admin_has_not_manually_toggled) }
    end

    context "when everything's ok" do
      let(:notification) do
        Notification.where("data::text LIKE ?", "%enable_upload_debug_mode%").last
      end
      let(:events) { DiscourseEvent.track_events { result } }
      let(:event) do
        events.find do |e|
          e[:event_name] == :upcoming_change_enabled &&
            e[:params].first == :enable_upload_debug_mode
        end
      end

      it { is_expected.to run_successfully }

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

        data = JSON.parse(notification.data)
        expect(data["upcoming_change_names"]).to eq(["enable_upload_debug_mode"])
        expect(data["upcoming_change_humanized_names"]).to eq(["Enable upload debug mode"])
        expect(data["count"]).to eq(1)
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
        expect(event[:params]).to eq([:enable_upload_debug_mode])
      end

      context "when there is an existing unread notification" do
        before do
          Fabricate(
            :notification,
            user: admin,
            notification_type: Notification.types[:upcoming_change_automatically_promoted],
            read: false,
            data: {
              upcoming_change_names: ["other_change"],
              upcoming_change_humanized_names: ["Other change"],
              count: 1,
            }.to_json,
          )
        end

        it "skips sending email when consolidating notifications" do
          allow(Notification::Action::BulkCreate).to receive(:call).and_call_original

          result

          expect(Notification::Action::BulkCreate).to have_received(:call).with(
            satisfy { |args| args[:skip_send_email] == true },
          )
        end

        it "consolidates into a single notification per admin" do
          result

          notifications =
            Notification.where(
              notification_type: Notification.types[:upcoming_change_automatically_promoted],
              user_id: admin.id,
            )
          expect(notifications.count).to eq(1)

          data = JSON.parse(notifications.first.data)
          expect(data["upcoming_change_names"]).to contain_exactly(
            "other_change",
            "enable_upload_debug_mode",
          )
          expect(data["count"]).to eq(2)
        end
      end

      context "when there is an existing read notification" do
        before do
          Fabricate(
            :notification,
            user: admin,
            notification_type: Notification.types[:upcoming_change_automatically_promoted],
            read: true,
            data: {
              upcoming_change_names: ["other_change"],
              upcoming_change_humanized_names: ["Other change"],
              count: 1,
            }.to_json,
          )
        end

        it "does not skip sending email when not consolidating notifications" do
          allow(Notification::Action::BulkCreate).to receive(:call).and_call_original

          result

          expect(Notification::Action::BulkCreate).to have_received(:call).with(
            satisfy { |args| args[:skip_send_email] == false },
          )
        end

        it "does not consolidate with the read notification" do
          result

          notifications =
            Notification.where(
              notification_type: Notification.types[:upcoming_change_automatically_promoted],
              user_id: admin.id,
            )
          expect(notifications.count).to eq(2)
        end
      end

      context "when the same change is already in an unread notification" do
        before do
          Fabricate(
            :notification,
            user: admin,
            notification_type: Notification.types[:upcoming_change_automatically_promoted],
            read: false,
            data: {
              upcoming_change_names: ["enable_upload_debug_mode"],
              upcoming_change_humanized_names: ["Enable upload debug mode"],
              count: 1,
            }.to_json,
          )
        end

        it "deduplicates the change names" do
          result

          notifications =
            Notification.where(
              notification_type: Notification.types[:upcoming_change_automatically_promoted],
              user_id: admin.id,
            )
          expect(notifications.count).to eq(1)

          data = JSON.parse(notifications.first.data)
          expect(data["upcoming_change_names"]).to eq(["enable_upload_debug_mode"])
          expect(data["count"]).to eq(1)
        end
      end

      context "when there is an existing notification with the old data format" do
        before do
          Fabricate(
            :notification,
            user: admin,
            notification_type: Notification.types[:upcoming_change_automatically_promoted],
            read: false,
            data: {
              upcoming_change_name: "other_change",
              upcoming_change_humanized_name: "Other change",
            }.to_json,
          )
        end

        it "merges old format into the new array format" do
          result

          notifications =
            Notification.where(
              notification_type: Notification.types[:upcoming_change_automatically_promoted],
              user_id: admin.id,
            )
          expect(notifications.count).to eq(1)

          data = JSON.parse(notifications.first.data)
          expect(data["upcoming_change_names"]).to contain_exactly(
            "other_change",
            "enable_upload_debug_mode",
          )
          expect(data["count"]).to eq(2)
        end
      end
    end
  end
end
