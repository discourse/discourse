# frozen_string_literal: true

describe "Drafts dropdown", type: :system do
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  let(:composer) { PageObjects::Components::Composer.new }
  let(:drafts_dropdown) { PageObjects::Components::DraftsMenu.new }
  let(:discard_draft_modal) { PageObjects::Modals::DiscardDraft.new }

  before { sign_in(user) }

  describe "with no drafts" do
    it "does not display drafts dropdown" do
      page.visit "/"
      expect(drafts_dropdown).to be_hidden
    end

    it "adds a draft dropdown menu when a draft is available" do
      page.visit "/new-topic"
      composer.fill_content("This is a draft")

      expect(drafts_dropdown).to be_visible
    end
  end

  describe "with multiple drafts" do
    before do
      Draft.set(
        user,
        Draft::NEW_TOPIC,
        0,
        {
          title: "This is a test topic",
          reply: "Lorem ipsum dolor sit amet, consectetur adipiscing elit.",
        }.to_json,
      )

      5.times do |i|
        topic = Fabricate(:topic, user: user)
        Draft.set(user, topic.draft_key, 0, { reply: "test reply #{i}" }.to_json)
      end
    end

    it "displays the correct draft count" do
      page.visit "/"
      drafts_dropdown.open

      expect(drafts_dropdown).to be_open

      expect(drafts_dropdown.draft_item_count).to eq(4)
      expect(drafts_dropdown.other_drafts_count).to eq(2)

      drafts_dropdown.find(".topic-drafts-item:first-child").click

      expect(drafts_dropdown).to be_closed

      expect(composer).to be_opened
      composer.create

      wait_for { Draft.count == 5 }

      page.visit "/"
      drafts_dropdown.open

      expect(drafts_dropdown.draft_item_count).to eq(4)
      expect(drafts_dropdown.other_drafts_count).to eq(1)
    end

    it "shows the view all drafts when there are other drafts to display" do
      page.visit "/"
      drafts_dropdown.open

      expect(drafts_dropdown).to be_open
      expect(drafts_dropdown).to have_view_all_link
    end

    it "does not show the view all drafts link when all drafts are displayed" do
      Draft.where(user_id: user.id).order("created_at DESC").limit(2).destroy_all

      page.visit "/"
      drafts_dropdown.open

      expect(drafts_dropdown).to be_open
      expect(drafts_dropdown).to have_no_view_all_link
    end
  end

  describe "with private category" do
    fab!(:group)
    fab!(:group_user) { Fabricate(:group_user, user: user, group: group) }
    fab!(:category) { Fabricate(:private_category, group: group, permission_type: 3) }
    fab!(:subcategory) do
      Fabricate(
        :private_category,
        parent_category_id: category.id,
        group: group,
        permission_type: 1,
      )
    end

    let(:category_page) { PageObjects::Pages::Category.new }

    before do
      SiteSetting.default_subcategory_on_read_only_category = false

      Draft.set(
        user,
        Draft::NEW_TOPIC,
        0,
        { title: "This is a test topic", reply: "Lorem ipsum dolor sit amet" }.to_json,
      )
    end

    it "disables the drafts dropdown menu when new topic button is disabled" do
      category_page.visit(category)

      expect(category_page).to have_button("New Topic", disabled: true)
      expect(drafts_dropdown).to be_enabled
    end
  end
end
