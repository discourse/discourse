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

    it "shows the view all drafts when draft count exceeds the draft menu limit" do
      page.visit "/"
      drafts_dropdown.open

      expect(drafts_dropdown).to be_open
      expect(drafts_dropdown).not_to have_view_all_link

      # remove the last 2 drafts
      Draft.where(user_id: user.id).order("created_at DESC").limit(2).destroy_all

      page.visit "/"
      drafts_dropdown.open

      expect(drafts_dropdown).to be_open
      expect(drafts_dropdown).to have_no_view_all_link
    end
  end

  describe "with private category" do
    fab!(:category) { Fabricate(:private_category) }

    it "disabled the drafts dropdown menu" do
      page.visit "/c/#{category.slug}"
      expect(drafts_dropdown).to be_disabled
    end
  end
end
