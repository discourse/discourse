# frozen_string_literal: true

RSpec.shared_examples "User Sidebar Serializer Attributes" do |serializer_klass|
  fab!(:user) { Fabricate(:user) }

  let(:serializer) { serializer_klass.new(user, scope: Guardian.new(user), root: false) }

  before { SiteSetting.navigation_menu = "sidebar" }

  describe "#sidebar_category_ids" do
    fab!(:group) { Fabricate(:group) }
    fab!(:category) { Fabricate(:category) }
    fab!(:category_2) { Fabricate(:category) }
    fab!(:private_category) { Fabricate(:private_category, group: group) }
    fab!(:category_sidebar_section_link) do
      Fabricate(:category_sidebar_section_link, user: user, linkable: category)
    end
    fab!(:category_sidebar_section_link_2) do
      Fabricate(:category_sidebar_section_link, user: user, linkable: category_2)
    end
    fab!(:category_sidebar_section_link_3) do
      Fabricate(:category_sidebar_section_link, user: user, linkable: private_category)
    end

    it "is not included when navigation menu is legacy" do
      SiteSetting.navigation_menu = "legacy"

      json = serializer.as_json

      expect(json[:sidebar_category_ids]).to eq(nil)
    end

    it 'serializes only the categories that the user can see when sidebar has been enabled"' do
      SiteSetting.navigation_menu = "sidebar"

      json = serializer.as_json

      expect(json[:sidebar_category_ids]).to eq([category.id, category_2.id])

      group.add(user)
      serializer = serializer_klass.new(user, scope: Guardian.new(user), root: false)
      json = serializer.as_json

      expect(json[:sidebar_category_ids]).to eq([category.id, category_2.id, private_category.id])
    end
  end

  describe "#sidebar_tags" do
    fab!(:tag) { Fabricate(:tag, name: "foo", description: "foo tag") }
    fab!(:pm_tag) do
      Fabricate(:tag, name: "bar", pm_topic_count: 5, staff_topic_count: 0, public_topic_count: 0)
    end
    fab!(:hidden_tag) { Fabricate(:tag, name: "secret") }
    fab!(:staff_tag_group) do
      Fabricate(:tag_group, permissions: { "staff" => 1 }, tag_names: ["secret"])
    end
    fab!(:tag_sidebar_section_link) do
      Fabricate(:tag_sidebar_section_link, user: user, linkable: tag)
    end
    fab!(:tag_sidebar_section_link_2) do
      Fabricate(:tag_sidebar_section_link, user: user, linkable: pm_tag)
    end
    fab!(:tag_sidebar_section_link_3) do
      Fabricate(:tag_sidebar_section_link, user: user, linkable: hidden_tag)
    end

    it "is not included when navigation menu is legacy" do
      SiteSetting.navigation_menu = "legacy"
      SiteSetting.tagging_enabled = true

      json = serializer.as_json

      expect(json[:sidebar_tags]).to eq(nil)
    end

    it "is not included when tagging has not been enabled" do
      SiteSetting.navigation_menu = "sidebar"
      SiteSetting.tagging_enabled = false

      json = serializer.as_json

      expect(json[:sidebar_tags]).to eq(nil)
    end

    it "serializes only the tags that the user can see when sidebar and tagging has been enabled" do
      SiteSetting.navigation_menu = "sidebar"
      SiteSetting.tagging_enabled = true

      json = serializer.as_json

      expect(json[:sidebar_tags]).to contain_exactly(
        { name: tag.name, pm_only: false, description: tag.description },
        { name: pm_tag.name, pm_only: true, description: nil },
      )

      user.update!(admin: true)

      json = serializer.as_json

      expect(json[:sidebar_tags]).to contain_exactly(
        { name: tag.name, pm_only: false, description: tag.description },
        { name: pm_tag.name, pm_only: true, description: nil },
        { name: hidden_tag.name, pm_only: false, description: nil },
      )
    end
  end

  describe "#display_sidebar_tags" do
    fab!(:tag) { Fabricate(:tag) }

    it "should not be included in serialised object when navigation menu is legacy" do
      SiteSetting.tagging_enabled = true
      SiteSetting.navigation_menu = "legacy"

      expect(serializer.as_json[:display_sidebar_tags]).to eq(nil)
    end

    it "should not be included in serialised object when tagging has been disabled" do
      SiteSetting.tagging_enabled = false

      expect(serializer.as_json[:display_sidebar_tags]).to eq(nil)
    end

    it "should be true when user has visible tags" do
      SiteSetting.tagging_enabled = true

      Fabricate(:tag_group, permissions: { "staff" => 1 }, tag_names: [tag.name])
      user.update!(admin: true)

      expect(serializer.as_json[:display_sidebar_tags]).to eq(true)
    end

    it "should be false when user has no visible tags" do
      SiteSetting.tagging_enabled = true

      Fabricate(:tag_group, permissions: { "staff" => 1 }, tag_names: [tag.name])

      expect(serializer.as_json[:display_sidebar_tags]).to eq(false)
    end
  end
end
