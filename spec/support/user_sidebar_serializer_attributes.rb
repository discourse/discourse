# frozen_string_literal: true

RSpec.shared_examples "User Sidebar Serializer Attributes" do |serializer_klass|
  fab!(:user) { Fabricate(:user) }

  let(:serializer) { serializer_klass.new(user, scope: Guardian.new(user), root: false) }

  before do
    SiteSetting.navigation_menu = "sidebar"
  end

  describe "#sidebar_list_destination" do
    it 'is not included when navigation menu is legacy' do
      SiteSetting.navigation_menu = "legacy"

      expect(serializer.as_json[:sidebar_list_destination]).to eq(nil)
    end

    it "returns choosen value or default" do
      expect(serializer.as_json[:sidebar_list_destination]).to eq(SiteSetting.default_sidebar_list_destination)

      user.user_option.update!(sidebar_list_destination: "unread_new")

      expect(serializer.as_json[:sidebar_list_destination]).to eq("unread_new")
    end
  end

  describe '#sidebar_category_ids' do
    fab!(:group) { Fabricate(:group) }
    fab!(:category) { Fabricate(:category) }
    fab!(:category_2) { Fabricate(:category) }
    fab!(:private_category) { Fabricate(:private_category, group: group) }
    fab!(:category_sidebar_section_link) { Fabricate(:category_sidebar_section_link, user: user, linkable: category) }
    fab!(:category_sidebar_section_link_2) { Fabricate(:category_sidebar_section_link, user: user, linkable: category_2) }
    fab!(:category_sidebar_section_link_3) { Fabricate(:category_sidebar_section_link, user: user, linkable: private_category) }

    it "is not included when navigation menu is legacy" do
      SiteSetting.navigation_menu = "legacy"

      json = serializer.as_json

      expect(json[:sidebar_category_ids]).to eq(nil)
    end

    it 'serializes only the categories that the user can see when sidebar has been enabled"' do
      SiteSetting.navigation_menu = "sidebar"

      json = serializer.as_json

      expect(json[:sidebar_category_ids]).to eq([
        category.id,
        category_2.id
      ])

      group.add(user)
      serializer = serializer_klass.new(user, scope: Guardian.new(user), root: false)
      json = serializer.as_json

      expect(json[:sidebar_category_ids]).to eq([
        category.id,
        category_2.id,
        private_category.id
      ])
    end
  end

  describe '#sidebar_tags' do
    fab!(:tag) { Fabricate(:tag, name: "foo") }
    fab!(:pm_tag) { Fabricate(:tag, name: "bar", pm_topic_count: 5, topic_count: 0) }
    fab!(:hidden_tag) { Fabricate(:tag, name: "secret") }
    fab!(:staff_tag_group) { Fabricate(:tag_group, permissions: { "staff" => 1 }, tag_names: ["secret"]) }
    fab!(:tag_sidebar_section_link) { Fabricate(:tag_sidebar_section_link, user: user, linkable: tag) }
    fab!(:tag_sidebar_section_link_2) { Fabricate(:tag_sidebar_section_link, user: user, linkable: pm_tag) }
    fab!(:tag_sidebar_section_link_3) { Fabricate(:tag_sidebar_section_link, user: user, linkable: hidden_tag) }

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
        { name: tag.name, pm_only: false },
        { name: pm_tag.name, pm_only: true }
      )

      user.update!(admin: true)

      json = serializer.as_json

      expect(json[:sidebar_tags]).to contain_exactly(
        { name: tag.name, pm_only: false },
        { name: pm_tag.name, pm_only: true },
        { name: hidden_tag.name, pm_only: false }
      )
    end
  end

  describe "#display_sidebar_tags" do
    fab!(:tag) { Fabricate(:tag) }

    it 'should not be included in serialised object when navigation menu is legacy' do
      SiteSetting.tagging_enabled = true
      SiteSetting.navigation_menu = "legacy"

      expect(serializer.as_json[:display_sidebar_tags]).to eq(nil)
    end

    it 'should not be included in serialised object when tagging has been disabled' do
      SiteSetting.tagging_enabled = false

      expect(serializer.as_json[:display_sidebar_tags]).to eq(nil)
    end

    it 'should be true when user has visible tags' do
      SiteSetting.tagging_enabled = true

      Fabricate(:tag_group, permissions: { "staff" => 1 }, tag_names: [tag.name])
      user.update!(admin: true)

      expect(serializer.as_json[:display_sidebar_tags]).to eq(true)
    end

    it 'should be false when user has no visible tags' do
      SiteSetting.tagging_enabled = true

      Fabricate(:tag_group, permissions: { "staff" => 1 }, tag_names: [tag.name])

      expect(serializer.as_json[:display_sidebar_tags]).to eq(false)
    end
  end
end
