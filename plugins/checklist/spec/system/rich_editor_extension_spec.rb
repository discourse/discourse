# frozen_string_literal: true

describe "Composer - ProseMirror editor - Checklist extension", type: :system do
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  let(:composer) { PageObjects::Components::Composer.new }
  let(:rich) { composer.rich_editor }
  let(:checklist) { PageObjects::Components::RichChecklist.new(rich) }

  before do
    sign_in(user)
    SiteSetting.rich_editor = true
  end

  def open_composer_and_toggle_rich_editor
    page.visit "/new-topic"
    expect(composer).to be_opened
    composer.toggle_rich_editor
  end

  def click_checklist_toolbar_option
    find(".toolbar__button.list").click
    find("button[data-name='list-checklist']").click
  end

  describe "checklist functionality" do
    it "toggles checked state when clicking checkbox" do
      open_composer_and_toggle_rich_editor
      rich.click

      rich.send_keys("[ ] Item 1")
      expect(checklist).to have_unchecked(count: 1)

      checklist.click_checkbox
      expect(checklist).to have_checked(count: 1)
    end

    it "shows checklist option in toolbar" do
      open_composer_and_toggle_rich_editor
      rich.click

      find(".toolbar__button.list").click

      expect(page).to have_css("button[data-name='list-checklist']")
    end
  end

  describe "checklist structure" do
    it "creates proper list structure with toolbar" do
      open_composer_and_toggle_rich_editor
      rich.click

      click_checklist_toolbar_option
      rich.send_keys("First item")

      expect(checklist).to have_items(count: 1)
      expect(checklist).to have_checkboxes(count: 1)
    end

    it "continues checklist on Enter" do
      open_composer_and_toggle_rich_editor
      rich.click

      click_checklist_toolbar_option
      rich.send_keys("First item")
      rich.send_keys(:enter)

      expect(checklist).to have_items(count: 2)
      expect(checklist).to have_checkboxes(count: 2)
    end

    it "allows double-Enter to escape checklist" do
      open_composer_and_toggle_rich_editor
      rich.click

      click_checklist_toolbar_option
      rich.send_keys("First item")
      rich.send_keys(:enter)

      expect(checklist).to have_checkboxes(count: 2)

      rich.send_keys(:enter)

      expect(checklist).to have_checkboxes(count: 1)
      expect(checklist).to have_items(count: 1)
    end
  end

  describe "backspace behavior" do
    it "joins with previous item when backspacing at start of checklist item with content" do
      open_composer_and_toggle_rich_editor
      rich.click

      click_checklist_toolbar_option
      rich.send_keys("First item")
      rich.send_keys(:enter)
      rich.send_keys("Second item")

      expect(checklist).to have_checkboxes(count: 2)
      expect(checklist).to have_items(count: 2)

      rich.send_keys(:home)
      rich.send_keys(:backspace)

      expect(checklist).to have_checkboxes(count: 1)
      expect(rich).to have_text("First itemSecond item")
    end

    it "joins with previous item when backspacing on empty checklist item" do
      open_composer_and_toggle_rich_editor
      rich.click

      click_checklist_toolbar_option
      rich.send_keys("First item")
      rich.send_keys(:enter)

      expect(checklist).to have_checkboxes(count: 2)

      rich.send_keys(:backspace)

      expect(checklist).to have_checkboxes(count: 1)
      expect(rich).to have_text("First item")
    end

    it "removes checkbox when backspacing on first/only checklist item" do
      open_composer_and_toggle_rich_editor
      rich.click

      click_checklist_toolbar_option
      rich.send_keys("Only item")

      expect(checklist).to have_checkboxes(count: 1)
      expect(checklist).to have_items(count: 1)

      rich.send_keys(:home)
      rich.send_keys(:backspace)

      expect(checklist).to have_no_checkboxes
      expect(rich).to have_text("Only item")
    end
  end
end
