# frozen_string_literal: true

RSpec.describe BasicGroupHistorySerializer do
  describe "#as_json" do
    fab!(:group)
    fab!(:group_owner, :user)
    fab!(:moderator)
    fab!(:admin)

    let(:histories) do
      %w[
        public_exit
        incoming_email
        has_messages
        automatic_membership_email_domains
        email_password
        smtp_server
        imap_server
        unknown_setting
      ].map do |subject|
        Fabricate.build(
          :group_history,
          group: group,
          acting_user: admin,
          target_user: nil,
          action: GroupHistory.actions[:change_group_setting],
          subject: subject,
          prev_value: "previous #{subject}",
          new_value: "current #{subject}",
        )
      end
    end

    let(:owner_values) do
      histories
        .to_h { |history| [history.subject, [I18n.t("staff_action_logs.redacted")] * 2] }
        .merge("public_exit" => ["previous public_exit", "current public_exit"])
    end

    it "shows only owner settings to a group owner" do
      SiteSetting.moderators_manage_groups = true
      group.add_owner(group_owner)

      values =
        histories.to_h do |history|
          json = described_class.new(history, scope: group_owner.guardian, root: false).as_json
          [json.fetch(:subject), json.values_at(:prev_value, :new_value)]
        end

      expect(values).to eq(owner_values)
    end

    it "shows staff settings to a moderator owner" do
      SiteSetting.moderators_manage_groups = false
      group.add_owner(moderator)

      values =
        histories.to_h do |history|
          json = described_class.new(history, scope: moderator.guardian, root: false).as_json
          [json.fetch(:subject), json.values_at(:prev_value, :new_value)]
        end

      expect(values).to eq(
        owner_values.merge(
          "incoming_email" => ["previous incoming_email", "current incoming_email"],
          "has_messages" => ["previous has_messages", "current has_messages"],
        ),
      )
    end

    it "shows membership domains to a moderator who can manage groups" do
      SiteSetting.moderators_manage_groups = true

      values =
        histories.to_h do |history|
          json = described_class.new(history, scope: moderator.guardian, root: false).as_json
          [json.fetch(:subject), json.values_at(:prev_value, :new_value)]
        end

      expect(values).to eq(
        owner_values.merge(
          "incoming_email" => ["previous incoming_email", "current incoming_email"],
          "has_messages" => ["previous has_messages", "current has_messages"],
          "automatic_membership_email_domains" => [
            "previous automatic_membership_email_domains",
            "current automatic_membership_email_domains",
          ],
        ),
      )
    end

    it "shows all settings to an administrator" do
      values =
        histories.to_h do |history|
          json = described_class.new(history, scope: admin.guardian, root: false).as_json
          [json.fetch(:subject), json.values_at(:prev_value, :new_value)]
        end

      expect(values).to eq(
        histories.to_h { |history| [history.subject, [history.prev_value, history.new_value]] },
      )
    end
  end
end
