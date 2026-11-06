# frozen_string_literal: true

RSpec.describe BasicGroupHistorySerializer do
  fab!(:group)
  fab!(:regular_user, :user)

  it "redacts restricted values without a requesting scope" do
    %w[incoming_email automatic_membership_email_domains email_password].each do |subject|
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
