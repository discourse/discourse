# frozen_string_literal: true

RSpec.describe BasicGroupUserSerializer do
  fab!(:group) { Fabricate(:group) }
  fab!(:user) { Fabricate(:user) }

  before { group.add(user) }

  describe "#owner" do
    describe "when scoped to the user" do
      it "should be false" do
        json = described_class.new(GroupUser.last, scope: Guardian.new(user), root: false).as_json

        expect(json[:owner]).to eq(false)
      end
    end

    describe "when not scoped to the user" do
      it "should be nil" do
        json = described_class.new(GroupUser.last, scope: Guardian.new, root: false).as_json

        expect(json[:owner]).to eq(nil)
      end
    end
  end
end
