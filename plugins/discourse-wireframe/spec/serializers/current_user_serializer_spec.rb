# frozen_string_literal: true

RSpec.describe CurrentUserSerializer do
  fab!(:allowed_group, :group)
  fab!(:allowed_user, :user)
  fab!(:other_user, :user)

  before do
    SiteSetting.wireframe_enabled = true
    SiteSetting.wireframe_allowed_groups = allowed_group.id.to_s
    allowed_group.add(allowed_user)
  end

  it "serializes whether the user belongs to a wireframe access group" do
    allowed_json =
      described_class.new(allowed_user, scope: Guardian.new(allowed_user), root: false).as_json
    other_json =
      described_class.new(other_user, scope: Guardian.new(other_user), root: false).as_json

    expect(allowed_json[:can_use_wireframe]).to eq(true)
    expect(other_json[:can_use_wireframe]).to eq(false)
  end
end
