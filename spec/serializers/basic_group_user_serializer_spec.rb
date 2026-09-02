# frozen_string_literal: true

RSpec.describe BasicGroupUserSerializer do
  fab!(:group)
  fab!(:user)

  before { group.add(user) }

  describe "#owner" do
    describe "when scoped to the user" do
      it "is false" do
        json = described_class.new(GroupUser.last, scope: Guardian.new(user), root: false).as_json

        expect(json[:owner]).to eq(false)
      end
    end

    describe "when not scoped to the user" do
      it "is nil" do
        json = described_class.new(GroupUser.last, scope: Guardian.new, root: false).as_json

        expect(json[:owner]).to eq(nil)
      end
    end
  end
end
