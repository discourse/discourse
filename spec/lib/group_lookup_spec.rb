# frozen_string_literal: true

RSpec.describe GroupLookup do
  fab!(:group)

  describe "#[]" do
    before { @group_lookup = GroupLookup.new([group.id, nil]) }

    it "returns nil if group_id does not exists" do
      expect(@group_lookup[0]).to eq(nil)
    end

    it "returns nil if group_id is nil" do
      expect(@group_lookup[nil]).to eq(nil)
    end

    it "returns name if group_id exists" do
      expect(@group_lookup[group.id]).to eq(group.name)
    end
  end
end
