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

    it "does not have a my drafts link in sidebar" do
      page.visit "/"
      expect(page).to have_no_css(".sidebar-section-link[data-link-name='my-drafts']")
    end

    it "adds a draft dropdown menu when a draft is available" do
      page.visit "/new-topic"
      composer.fill_content("This is a draft")

      expect(drafts_dropdown).to be_visible
    end

    it "shows a my drafts link in sidebar when a draft is saved" do
      page.visit "/new-topic"

      composer.fill_content("This is a draft")
      composer.close

      expect(discard_draft_modal).to be_open
      discard_draft_modal.click_save

      visit "/"
      expect(page).to have_css(".sidebar-section-link[data-link-name='my-drafts']")
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
  end
end
