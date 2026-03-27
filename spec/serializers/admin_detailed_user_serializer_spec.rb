# frozen_string_literal: true

RSpec.describe AdminDetailedUserSerializer do
  fab!(:user) { Fabricate(:user, trust_level: 0) }
  fab!(:admin)
  fab!(:moderator)

  it "serializes name for admin even if enable_names setting is false" do
    serializer = AdminDetailedUserSerializer.new(user, scope: Guardian.new(admin), root: false)
    json = serializer.as_json
    expect(json[:name]).to eq(user.name)

    serializer = AdminDetailedUserSerializer.new(user, scope: Guardian.new(moderator), root: false)
    json = serializer.as_json
    expect(json[:name]).to be_nil
  end

  describe "#latest_export" do
    fab!(:user_export) { UserExport.create!(file_name: "test", user:, upload: Fabricate(:upload)) }

    it "is only included for admins" do
      serializer = described_class.new(user, scope: Guardian.new(admin), root: false)
      expect(serializer.as_json[:latest_export][:user_export][:id]).to eq(user_export.id)

      serializer = described_class.new(user, scope: Guardian.new(moderator), root: false)
      expect(serializer.as_json[:latest_export]).to be_nil
    end
  end

  describe "#single_sign_on_record" do
    fab!(:sso_record) do
      Fabricate(:single_sign_on_record, user: user, external_id: "external_user_id")
    end

    it "is always included for admins" do
      serializer = described_class.new(user, scope: Guardian.new(admin), root: false)
      expect(serializer.as_json[:single_sign_on_record][:external_id]).to eq("external_user_id")
    end

    it "is not included for moderators by default" do
      serializer = described_class.new(user, scope: Guardian.new(moderator), root: false)
      expect(serializer.as_json).not_to have_key(:single_sign_on_record)
    end

    it "is included for moderators when site setting is enabled" do
      SiteSetting.moderators_view_sso_details = true

      serializer = described_class.new(user, scope: Guardian.new(moderator), root: false)
      expect(serializer.as_json[:single_sign_on_record][:external_id]).to eq("external_user_id")
    end
  end

  describe "#external_ids" do
    fab!(:associated_account) do
      Fabricate(:user_associated_account, user: user, provider_name: "google_oauth2")
    end

    it "is only included for admins" do
      serializer = described_class.new(user, scope: Guardian.new(admin), root: false)
      expect(serializer.as_json[:external_ids]["google_oauth2"]).to eq(
        associated_account.provider_uid,
      )

      serializer = described_class.new(user, scope: Guardian.new(moderator), root: false)
      expect(serializer.as_json).not_to have_key(:external_ids)
    end

    it "is not included for moderators even with site setting enabled" do
      SiteSetting.moderators_view_sso_details = true

      serializer = described_class.new(user, scope: Guardian.new(moderator), root: false)
      expect(serializer.as_json).not_to have_key(:external_ids)
    end
  end

  describe "#groups" do
    fab!(:public_group) { Fabricate(:group, visibility_level: Group.visibility_levels[:public]) }
    fab!(:owner_only_group) do
      Fabricate(:group, visibility_level: Group.visibility_levels[:owners])
    end

    before do
      public_group.add(user)
      owner_only_group.add_owner(user)
    end

    it "filters groups based on visibility for moderators" do
      serializer = described_class.new(user, scope: Guardian.new(moderator), root: false)
      group_names = serializer.as_json[:groups].map { |g| g[:name] }

      expect(group_names).to include(public_group.name)
      expect(group_names).not_to include(owner_only_group.name)
    end

    it "shows all groups for admins" do
      serializer = described_class.new(user, scope: Guardian.new(admin), root: false)
      group_names = serializer.as_json[:groups].map { |g| g[:name] }

      expect(group_names).to include(public_group.name, owner_only_group.name)
    end
  end
end
