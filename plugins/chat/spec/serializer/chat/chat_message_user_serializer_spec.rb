# frozen_string_literal: true

RSpec.describe Chat::MessageUserSerializer do
  subject(:serializer) do
    user = Fabricate(:user, **params)
    guardian = Guardian.new(user)
    described_class.new(user, scope: guardian, root: nil).as_json
  end

  let(:params) do
    { trust_level: TrustLevel[1], admin: false, moderator: false, primary_group_id: nil }
  end

  context "with default user" do
    it "displays user as regular" do
      expect(serializer[:new_user]).to eq(false)
      expect(serializer[:staff]).to eq(false)
      expect(serializer[:admin]).to eq(false)
      expect(serializer[:moderator]).to eq(false)
      expect(serializer[:primary_group_name]).to be_blank
    end
  end

  context "when user is TL0" do
    before { params[:trust_level] = TrustLevel[0] }

    it "displays user as new" do
      expect(serializer[:new_user]).to eq(true)
    end
  end

  context "when user is staff" do
    before { params[:admin] = true }

    it "displays user as staff" do
      expect(serializer[:staff]).to eq(true)
    end
  end

  context "when user is admin" do
    before { params[:admin] = true }

    it "displays user as admin" do
      expect(serializer[:admin]).to eq(true)
    end
  end

  context "when user is moderator" do
    before { params[:moderator] = true }

    it "displays user as moderator" do
      expect(serializer[:moderator]).to eq(true)
    end
  end

  context "when user has a primary group" do
    fab!(:group)

    before { params[:primary_group_id] = group.id }

    it "displays user as moderator" do
      expect(serializer[:primary_group_name]).to eq(group.name)
    end
  end
end
