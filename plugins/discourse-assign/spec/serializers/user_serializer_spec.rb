# frozen_string_literal: true

RSpec.describe UserSerializer do
  fab!(:admin)
  fab!(:assignable_user, :user)
  fab!(:other_user, :user)
  fab!(:group) { Fabricate(:group, users: [assignable_user]) }

  before do
    SiteSetting.assign_enabled = true
    SiteSetting.assign_allowed_on_groups = group.id.to_s
  end

  def serialize(user, viewer)
    described_class.new(user, scope: viewer.guardian, root: false).as_json
  end

  it "serializes whether the viewed user can assign" do
    expect(serialize(assignable_user, admin)[:can_assign]).to eq(true)
    expect(serialize(other_user, admin)[:can_assign]).to eq(false)
  end

  it "includes can_assign only for users who can edit the viewed user" do
    expect(serialize(assignable_user, other_user)).not_to have_key(:can_assign)
  end
end
