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
end
