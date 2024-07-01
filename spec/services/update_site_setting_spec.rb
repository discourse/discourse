# frozen_string_literal: true

describe(UpdateSiteSetting) do
  fab!(:admin)

  def call_service(name, value, user: admin, allow_changing_hidden: false)
    described_class.call(
      setting_name: name,
      new_value: value,
      guardian: user.guardian,
      allow_changing_hidden:,
    )
  end

  context "when setting_name is blank" do
    it "fails the service contract" do
      expect(call_service(nil, "blah whatever")).to fail_a_contract

      expect(call_service(:"", "blah whatever")).to fail_a_contract
    end
  end

  context "when a non-admin user tries to change a setting" do
    it "fails the current_user_is_admin policy" do
      expect(call_service(:title, "some new title", user: Fabricate(:moderator))).to fail_a_policy(
        :current_user_is_admin,
      )
      expect(SiteSetting.title).not_to eq("some new title")
    end
  end

  context "when the user changes a hidden setting" do
    context "when allow_changing_hidden is false" do
      it "fails the setting_is_visible policy" do
        expect(call_service(:max_category_nesting, 3)).to fail_a_policy(:setting_is_visible)
        expect(SiteSetting.max_category_nesting).not_to eq(3)
      end
    end

    context "when allow_changing_hidden is true" do
      it "updates the specified setting" do
        expect(call_service(:max_category_nesting, 3, allow_changing_hidden: true)).to be_success
        expect(SiteSetting.max_category_nesting).to eq(3)
      end
    end
  end

  context "when the user changes a visible setting" do
    it "updates the specified setting" do
      expect(call_service(:title, "hello this is title")).to be_success
      expect(SiteSetting.title).to eq("hello this is title")
    end

    it "cleans up the new setting value before using it" do
      expect(call_service(:suggested_topics, "308viu")).to be_success
      expect(SiteSetting.suggested_topics).to eq(308)

      expect(call_service(:max_image_size_kb, "8zf843")).to be_success
      expect(SiteSetting.max_image_size_kb).to eq(8843)
    end

    it "creates an entry in the staff action logs" do
      expect do expect(call_service(:max_image_size_kb, 44_543)).to be_success end.to change {
        UserHistory.where(
          action: UserHistory.actions[:change_site_setting],
          subject: "max_image_size_kb",
        ).count
      }.by(1)
    end
  end
end
