# frozen_string_literal: true

RSpec.describe UserSerializer do
  before do
    SiteSetting.discourse_rewind_enabled = true
    freeze_time DateTime.parse("2024-12-15")
  end

  fab!(:admin) { Fabricate(:admin, created_at: DateTime.parse("2024-12-10")) }
  fab!(:user) { Fabricate(:user, created_at: DateTime.parse("2020-01-01")) }

  def serialize(user, viewer)
    described_class.new(user, scope: viewer.guardian, root: false).as_json
  end

  describe "#is_rewind_active" do
    it "returns the serialized user's eligibility when viewed by someone else" do
      expect(serialize(user, admin)[:is_rewind_active]).to eq(true)
      expect(serialize(admin, user)[:is_rewind_active]).to eq(false)
    end
  end
end
