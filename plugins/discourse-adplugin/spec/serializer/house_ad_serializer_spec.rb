# frozen_string_literal: true

describe AdPlugin::HouseAdSerializer do
  fab!(:user)
  fab!(:house_ad) do
    Fabricate(
      :house_ad,
      name: "Test Ad",
      html: "<div>Test HTML</div>",
      visible_to_logged_in_users: true,
      visible_to_anons: false,
    )
  end
  fab!(:category)
  fab!(:group)

  let(:guardian) { Guardian.new(user) }

  before { enable_current_plugin }

  describe "basic serialization" do
    it "serializes basic attributes" do
      serializer = AdPlugin::HouseAdSerializer.new(house_ad, root: false)
      json = serializer.as_json

      expect(json[:id]).to eq(house_ad.id)
      expect(json[:name]).to eq("Test Ad")
      expect(json[:html]).to eq("<div>Test HTML</div>")
      expect(json[:visible_to_logged_in_users]).to eq(true)
      expect(json[:visible_to_anons]).to eq(false)
      expect(json[:created_at]).to be_present
      expect(json[:updated_at]).to be_present
    end

    it "does not include groups by default" do
      house_ad.update!(group_ids: [group.id])
      serializer = AdPlugin::HouseAdSerializer.new(house_ad, root: false)
      json = serializer.as_json

      expect(json).not_to have_key(:groups)
    end

    it "does not include categories by default" do
      house_ad.update!(category_ids: [category.id])
      serializer = AdPlugin::HouseAdSerializer.new(house_ad, root: false)
      json = serializer.as_json

      expect(json).not_to have_key(:categories)
    end
  end

  context "with include_groups option" do
    it "includes empty array when no groups" do
      serializer =
        AdPlugin::HouseAdSerializer.new(
          house_ad,
          scope: guardian,
          root: false,
          include_groups: true,
        )
      json = serializer.as_json

      expect(json[:groups]).to eq([])
    end

    it "includes multiple groups" do
      group2 = Fabricate(:group)
      house_ad.update!(group_ids: [group.id, group2.id])
      serializer =
        AdPlugin::HouseAdSerializer.new(
          house_ad,
          scope: guardian,
          root: false,
          include_groups: true,
        )
      json = serializer.as_json

      expect(json[:groups].length).to eq(2)
      expect(json[:groups].map { |g| g[:id] }).to contain_exactly(group.id, group2.id)
    end
  end

  context "with include_categories option" do
    it "includes empty array when no categories" do
      serializer = AdPlugin::HouseAdSerializer.new(house_ad, root: false, include_categories: true)
      json = serializer.as_json

      expect(json[:categories]).to eq([])
    end

    it "includes multiple categories" do
      category2 = Fabricate(:category)
      house_ad.update!(category_ids: [category.id, category2.id])
      serializer = AdPlugin::HouseAdSerializer.new(house_ad, root: false, include_categories: true)
      json = serializer.as_json

      expect(json[:categories].length).to eq(2)
      expect(json[:categories].map { |c| c[:id] }).to contain_exactly(category.id, category2.id)
    end
  end

  context "with both groups and categories" do
    it "includes both when both options are set" do
      house_ad.update!(category_ids: [category.id], group_ids: [group.id])
      serializer =
        AdPlugin::HouseAdSerializer.new(
          house_ad,
          scope: guardian,
          root: false,
          include_categories: true,
          include_groups: true,
        )
      json = serializer.as_json

      expect(json[:categories]).to be_present
      expect(json[:categories].length).to eq(1)
      expect(json[:groups]).to be_present
      expect(json[:groups].length).to eq(1)
    end
  end
end
