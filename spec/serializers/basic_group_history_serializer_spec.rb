# frozen_string_literal: true

RSpec.describe BasicGroupHistorySerializer do
  describe "#as_json" do
    fab!(:group)
    fab!(:regular_user, :user)

    it "redacts restricted values without a requesting scope" do
      %w[
        incoming_email
        automatic_membership_email_domains
        email_password
        public_exit
        plugin_private_setting
      ].each do |subject|
        history =
          Fabricate.build(
            :group_history,
            group: group,
            subject: subject,
            prev_value: "previous value",
            new_value: "current value",
          )

        json = described_class.new(history, scope: nil, root: false).as_json

        expect(json.values_at(:prev_value, :new_value)).to eq(
          [I18n.t("staff_action_logs.redacted")] * 2,
        )
      end
    end

    it "preserves allowed settings for a group owner" do
      group.add_owner(regular_user)
      histories =
        %w[
          automatic
          name
          mentionable_level
          messageable_level
          visibility_level
          primary_group
          title
          grant_trust_level
          flair_upload_id
          flair_icon
          flair_bg_color
          flair_color
          bio_raw
          public_admission
          public_exit
          allow_membership_requests
          full_name
          default_notification_level
          membership_request_template
          members_visibility_level
          publish_read_state
        ].map do |attribute|
          Fabricate.build(
            :group_history,
            group: group,
            subject: attribute,
            prev_value: "previous #{attribute}",
            new_value: "current #{attribute}",
          )
        end

      values =
        histories.to_h do |history|
          json = described_class.new(history, scope: regular_user.guardian, root: false).as_json
          [json.fetch(:subject), json.values_at(:prev_value, :new_value)]
        end

      expect(values).to eq(
        histories.to_h { |history| [history.subject, [history.prev_value, history.new_value]] },
      )
    end

    it "redacts the previous value when a restricted setting is cleared" do
      history =
        Fabricate.build(
          :group_history,
          group: group,
          subject: "incoming_email",
          prev_value: "private@example.com",
          new_value: "",
        )

      json = described_class.new(history, scope: regular_user.guardian, root: false).as_json

      expect(json.values_at(:prev_value, :new_value)).to eq(
        [I18n.t("staff_action_logs.redacted"), ""],
      )
    end

    it "preserves empty previous values and redacts new restricted values" do
      history =
        Fabricate.build(
          :group_history,
          group: group,
          subject: "incoming_email",
          prev_value: nil,
          new_value: "private@example.com",
        )

      json = described_class.new(history, scope: regular_user.guardian, root: false).as_json

      expect(json.values_at(:prev_value, :new_value)).to eq(
        [nil, I18n.t("staff_action_logs.redacted")],
      )
    end
  end
end
