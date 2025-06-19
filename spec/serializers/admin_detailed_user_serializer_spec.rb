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
end
