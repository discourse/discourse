# frozen_string_literal: true

RSpec.describe "Editing sidebar tags navigation", type: :system do
  fab!(:user) { Fabricate(:user) }
  fab!(:tag1) { Fabricate(:tag, name: "tag").tap { |tag| Fabricate.times(3, :topic, tags: [tag]) } }

  fab!(:tag2) do
    Fabricate(:tag, name: "tag2").tap { |tag| Fabricate.times(2, :topic, tags: [tag]) }
  end

  fab!(:tag3) do
    Fabricate(:tag, name: "tag3").tap { |tag| Fabricate.times(1, :topic, tags: [tag]) }
  end

  fab!(:tag4) do
    Fabricate(:tag, name: "tag4").tap do |tag|
      Fabricate.times(1, :topic, tags: [tag])

      # Ensures tags in tag groups are shown as well
      Fabricate(:tag_group, tags: [tag])
    end
  end

  # This tag should not be displayed in the modal as it has not been used in a topic
  fab!(:tag5) { Fabricate(:tag, name: "tag5") }

  let(:sidebar) { PageObjects::Components::NavigationMenu::Sidebar.new }

  before { sign_in(user) }

  shared_examples "a user can edit the sidebar tags navigation" do |mobile|
    it "allows a user to edit the sidebar tags navigation", mobile: mobile do
      visit "/latest"

      sidebar.open_on_mobile if mobile

      expect(sidebar).to have_tags_section
      expect(sidebar).to have_section_link(tag1.name)
      expect(sidebar).to have_section_link(tag2.name)
      expect(sidebar).to have_section_link(tag3.name)
      expect(sidebar).to have_section_link(tag4.name)

      modal = sidebar.click_edit_tags_button

      expect(modal).to have_right_title(I18n.t("js.sidebar.tags_form_modal.title"))
      try_until_success { expect(modal).to have_focus_on_filter_input }
      expect(modal).to have_tag_checkboxes([tag1, tag2, tag3, tag4])

      modal.toggle_tag_checkbox(tag1).toggle_tag_checkbox(tag2).save

      expect(modal).to be_closed

      sidebar.open_on_mobile if mobile

      expect(sidebar).to have_section_link(tag1.name)
      expect(sidebar).to have_section_link(tag2.name)
      expect(sidebar).to have_no_section_link(tag3.name)
      expect(sidebar).to have_no_section_link(tag4.name)

      visit "/latest"

      sidebar.open_on_mobile if mobile

      expect(sidebar).to have_section_link(tag1.name)
      expect(sidebar).to have_section_link(tag2.name)
      expect(sidebar).to have_no_section_link(tag3.name)
      expect(sidebar).to have_no_section_link(tag4.name)

      modal = sidebar.click_edit_tags_button
      modal.toggle_tag_checkbox(tag2).save

      expect(modal).to be_closed

      sidebar.open_on_mobile if mobile

      expect(sidebar).to have_section_link(tag1.name)
      expect(sidebar).to have_no_section_link(tag2.name)
      expect(sidebar).to have_no_section_link(tag3.name)
      expect(sidebar).to have_no_section_link(tag4.name)
    end
  end

  describe "when on desktop" do
    include_examples "a user can edit the sidebar tags navigation", false
  end

  describe "when on mobile" do
    include_examples "a user can edit the sidebar tags navigation", true
  end

  it "allows a user to filter the tags in the modal by the tag's name" do
    visit "/latest"

    expect(sidebar).to have_tags_section

    modal = sidebar.click_edit_tags_button

    modal.filter("tag")

    expect(modal).to have_tag_checkboxes([tag1, tag2, tag3, tag4])

    modal.filter("tag2")

    expect(modal).to have_tag_checkboxes([tag2])

    modal.filter("someinvalidterm")

    expect(modal).to have_no_tag_checkboxes
  end

  it "allows a user to deselect all tags in the modal which will display the site's top tags" do
    Fabricate(:tag_sidebar_section_link, user: user, linkable: tag1)

    visit "/latest"

    expect(sidebar).to have_tags_section
    expect(sidebar).to have_section_link(tag1.name)
    expect(sidebar).to have_no_section_link(tag2.name)
    expect(sidebar).to have_no_section_link(tag3.name)
    expect(sidebar).to have_no_section_link(tag4.name)

    modal = sidebar.click_edit_tags_button
    modal.deselect_all.save

    expect(sidebar).to have_section_link(tag1.name)
    expect(sidebar).to have_section_link(tag2.name)
    expect(sidebar).to have_section_link(tag3.name)
    expect(sidebar).to have_section_link(tag4.name)
  end

  it "allows a user to reset to the default navigation menu tags site setting" do
    Fabricate(:tag_sidebar_section_link, user: user, linkable: tag1)

    SiteSetting.default_navigation_menu_tags = "#{tag2.name}|#{tag3.name}"

    visit "/latest"

    expect(sidebar).to have_tags_section
    expect(sidebar).to have_section_link(tag1.name)
    expect(sidebar).to have_no_section_link(tag2.name)
    expect(sidebar).to have_no_section_link(tag3.name)
    expect(sidebar).to have_no_section_link(tag4.name)

    modal = sidebar.click_edit_tags_button
    modal.click_reset_to_defaults_button.save

    expect(modal).to be_closed
    expect(sidebar).to have_no_section_link(tag1.name)
    expect(sidebar).to have_section_link(tag2.name)
    expect(sidebar).to have_section_link(tag3.name)
    expect(sidebar).to have_no_section_link(tag4.name)
  end

  it "allows a user to filter the tag in the modal by selection" do
    Fabricate(:tag_sidebar_section_link, linkable: tag1, user: user)
    Fabricate(:tag_sidebar_section_link, linkable: tag2, user: user)

    visit "/latest"

    expect(sidebar).to have_tags_section

    modal = sidebar.click_edit_tags_button
    modal.filter_by_selected

    expect(modal).to have_tag_checkboxes([tag1, tag2])

    modal.filter("tag2")

    expect(modal).to have_tag_checkboxes([tag2])

    modal.filter("").filter_by_unselected

    expect(modal).to have_tag_checkboxes([tag3, tag4])

    modal.filter_by_all

    expect(modal).to have_tag_checkboxes([tag1, tag2, tag3, tag4])
  end

  it "loads more tags when the user scrolls views the last tag in the modal and there is more tags to load" do
    stub_const(TagsController, "LIST_LIMIT", 2) do
      visit "/latest"

      expect(sidebar).to have_tags_section

      modal = sidebar.click_edit_tags_button

      expect(modal).to have_tag_checkboxes([tag1, tag2, tag3, tag4])
    end
  end
end
