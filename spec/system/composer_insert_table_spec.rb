# frozen_string_literal: true

describe "Composer insert table" do
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:topic) { Fabricate(:topic, user: user) }
  fab!(:post) { create_post(user: user, topic: topic, raw: <<~RAW) }
    |Make | Model | Year|
    |--- | --- | ---|
    |Toyota | Supra | 1998|
  RAW

  let(:composer) { PageObjects::Components::Composer.new }
  let(:topic_page) { PageObjects::Pages::Topic.new }

  before { sign_in(user) }

  def use_composition_mode(mode)
    user.user_option.update!(composition_mode: UserOption.composition_mode_types[mode])
  end

  def insert_table
    find(".toolbar-menu__options-trigger").click
    find("button[data-name='toggle-spreadsheet']").click
  end

  context "with the Markdown editor" do
    before { use_composition_mode(:markdown) }

    it "inserts a Markdown table" do
      visit("/latest")
      find("#create-topic").click
      composer.fill_content("Some text")
      insert_table

      expect(composer).to have_value(<<~MD)
        Some text

        | Column 1 | Column 2 | Column 3 | Column 4 |
        | --- | --- | --- | --- |
        |  |  |  |  |
      MD
    end
  end

  context "with the rich editor" do
    before { use_composition_mode(:rich) }

    it "inserts a table with structural editing controls" do
      visit("/latest")
      find("#create-topic").click
      expect(composer).to have_rich_editor

      insert_table

      expect(composer.rich_editor).to have_css("table th", count: 4)
      expect(composer.rich_editor).to have_css("table th", text: "Column 1")
      expect(composer.rich_editor).to have_css(".composer-table__append", visible: :all)
    end
  end

  it "does not offer to edit tables in published posts" do
    topic_page.visit_topic(topic)

    expect(topic_page).to have_post_content(post_number: 1, content: "Toyota")
    expect(page).to have_no_css(".btn-edit-table", visible: :all)
  end
end
