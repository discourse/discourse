# frozen_string_literal: true

describe "Table Builder" do
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  let(:composer) { PageObjects::Components::Composer.new }
  let(:insert_table_modal) { PageObjects::Modals::InsertTable.new }
  fab!(:topic) { Fabricate(:topic, user: user) }
  fab!(:topic2) { Fabricate(:topic, user: user) }
  fab!(:post1) { create_post(user: user, topic: topic, raw: <<~RAW) }
    |Make   | Model   | Year|
    |--- | --- | ---|
    |Toyota | Supra   | 1998|
    |Nissan | Skyline | 1999|
    |Honda  | S2000  | 2001|
  RAW
  fab!(:post2) { create_post(user: user, topic: topic2, raw: <<~RAW) }
    | |  | |
    |--- | --- | ---|
    |Some | content | here|
    |1 | 2 | 3|
  RAW

  let(:topic_page) { PageObjects::Pages::Topic.new }

  before { sign_in(user) }

  def normalize_value(content)
    content.strip.gsub(/\s+/, " ").gsub(/\r\n/, "\n")
  end

  context "when creating a new table" do
    it "adds spreadsheet table items to the composer" do
      browser_page.goto("/latest").tap { SystemBrowserBootstrap.wait_for(browser_page) }
      browser_root.locator("#create-topic").filter(visible: true).click
      browser_root.locator(".toolbar-menu__options-trigger").filter(visible: true).click
      browser_root.locator("button[data-name='toggle-spreadsheet']").filter(visible: true).click
      insert_table_modal.type_in_cell(0, 0, "Item 1")
      insert_table_modal.type_in_cell(0, 1, "Item 2")
      insert_table_modal.type_in_cell(0, 2, "Item 3")
      insert_table_modal.type_in_cell(0, 3, "Item 4")
      insert_table_modal.click_insert_table

      created_table = <<~TABLE
            |Column 1 | Column 2 | Column 3 | Column 4|
            |--- | --- | --- | ---|
            |Item 1 | Item 2 | Item 3 | Item 4|
            | |  |  | |
            | |  |  | |
            | |  |  | |
            | |  |  | |
            | |  |  | |
          TABLE

      expect(normalize_value(composer.composer_input.input_value)).to eq(
        normalize_value(created_table),
      )
    end

    context "when cancelling table creation" do
      it "closes the modal when nothing changed" do
        browser_page.goto("/latest").tap { SystemBrowserBootstrap.wait_for(browser_page) }
        browser_root.locator("#create-topic").filter(visible: true).click
        browser_root.locator(".toolbar-menu__options-trigger").filter(visible: true).click
        browser_root.locator("button[data-name='toggle-spreadsheet']").filter(visible: true).click
        insert_table_modal.cancel
        expect(
          browser_root.locator(".insert-table-modal").filter(visible: true),
        ).to PlaywrightMatchers.have_count(0)
      end

      it "warns about unsaved changes" do
        browser_page.goto("/latest").tap { SystemBrowserBootstrap.wait_for(browser_page) }
        browser_root.locator("#create-topic").filter(visible: true).click
        browser_root.locator(".toolbar-menu__options-trigger").filter(visible: true).click
        browser_root.locator("button[data-name='toggle-spreadsheet']").filter(visible: true).click
        insert_table_modal.type_in_cell(0, 0, "Item 1")
        insert_table_modal.cancel
        expect(
          browser_root.locator(".dialog-container .dialog-content").filter(visible: true),
        ).not_to PlaywrightMatchers.have_count(0)
      end
    end
  end

  context "when editing a table" do
    it "prefills the spreadsheet from the post's Markdown table" do
      topic_page.visit_topic(topic)
      topic_page.locator(".btn-edit-table").click
      expect(
        browser_root.locator(".insert-table-modal").filter(visible: true),
      ).not_to PlaywrightMatchers.have_count(0)

      expected_table_content = [
        %w[Toyota Supra 1998],
        %w[Nissan Skyline 1999],
        %w[Honda S2000 2001],
      ]

      expected_table_content.each_with_index do |row, row_index|
        row.each_with_index do |content, col_index|
          expect(insert_table_modal).to have_content_in_cell(row_index, col_index, content)
        end
      end
    end

    it "updates the post with the new table content" do
      topic_page.visit_topic(topic)
      topic_page.locator(".btn-edit-table").click
      expect(
        browser_root.locator(".insert-table-modal").filter(visible: true),
      ).not_to PlaywrightMatchers.have_count(0)
      insert_table_modal.type_in_cell(1, 1, " GTR")
      insert_table_modal.click_insert_table

      updated_post = <<~RAW
            |Make | Model | Year|
            |--- | --- | ---|
            |Toyota | Supra | 1998|
            |Nissan | Skyline GTR | 1999|
            |Honda | S2000 | 2001|
          RAW

      expect(normalize_value(post1.reload.raw)).to eq(normalize_value(updated_post))
    end

    it "preserves an empty table header" do
      topic_page.visit_topic(topic2)
      topic_page.locator(".btn-edit-table").click
      expect(
        browser_root.locator(".insert-table-modal").filter(visible: true),
      ).not_to PlaywrightMatchers.have_count(0)
      insert_table_modal.type_in_cell(0, 0, " updated")
      insert_table_modal.click_insert_table

      updated_post = <<~RAW
            | |  | |
            |--- | --- | ---|
            |Some updated | content | here|
            |1 | 2 | 3|
          RAW

      expect(normalize_value(post2.reload.raw)).to eq(normalize_value(updated_post))
    end

    context "when adding an edit reason" do
      it "adds the edit reason to the revision history" do
        edit_reason = "Updated Nissan model"

        topic_page.visit_topic(topic)
        topic_page.locator(".btn-edit-table").click
        expect(
          browser_root.locator(".insert-table-modal").filter(visible: true),
        ).not_to PlaywrightMatchers.have_count(0)
        insert_table_modal.type_in_cell(1, 1, " GTR")
        insert_table_modal.click_edit_reason
        insert_table_modal.type_edit_reason(edit_reason)
        insert_table_modal.click_insert_table
        wait_for { post1.reload.edit_reason == edit_reason }
        expect(post1.reload.edit_reason).to eq(edit_reason)
      end
    end

    context "when cancelling table creation" do
      it "closes the modal when nothing changed" do
        topic_page.visit_topic(topic)
        topic_page.locator(".btn-edit-table").click
        expect(
          browser_root.locator(".insert-table-modal").filter(visible: true),
        ).not_to PlaywrightMatchers.have_count(0)
        insert_table_modal.cancel
        expect(
          browser_root.locator(".insert-table-modal").filter(visible: true),
        ).to PlaywrightMatchers.have_count(0)
      end

      it "closes the modal if there are no changes in a table with empty headers" do
        topic_page.visit_topic(topic2)
        topic_page.locator(".btn-edit-table").click
        insert_table_modal.cancel

        expect(
          browser_root.locator(".insert-table-modal").filter(visible: true),
        ).to PlaywrightMatchers.have_count(0)
      end

      it "warns about unsaved changes" do
        topic_page.visit_topic(topic)
        topic_page.locator(".btn-edit-table").click
        expect(
          browser_root.locator(".insert-table-modal").filter(visible: true),
        ).not_to PlaywrightMatchers.have_count(0)
        insert_table_modal.type_in_cell(1, 1, " GTR")
        insert_table_modal.cancel
        expect(
          browser_root.locator(".dialog-container .dialog-content").filter(visible: true),
        ).not_to PlaywrightMatchers.have_count(0)
      end
    end

    it "ignores default Discourse keyboard shortcuts" do
      topic_page.visit_topic(topic)
      topic_page.locator(".btn-edit-table").click
      insert_table_modal.find_cell(0, 0).wait_for(state: "visible")
      browser_page.keyboard.press(%w[Shift s].join("+"))
      expect(
        browser_root.locator(".insert-table-modal").filter(visible: true),
      ).not_to PlaywrightMatchers.have_count(0)
      expect(
        browser_root.locator(".share-topic-modal").filter(visible: true),
      ).to PlaywrightMatchers.have_count(0)
    end

    it "does not show duplicate edit buttons on quoted tables" do
      raw = <<~MD
        [quote="#{user.username}, post:#{post1.post_number}, topic:#{topic.id}"]
        |Make | Model | Year|
        | - | - | - |
        | Toyota | Supra | 1998 |
        [/quote]
      MD

      quoting_post = create_post(user:, topic:, raw:)
      topic_page.visit_topic(topic)

      within_browser(
        browser_root.locator("#post_#{quoting_post.post_number}").filter(visible: true),
      ) { expect(browser_root.locator(".btn-edit-table")).to PlaywrightMatchers.have_count(1) }
    end
  end
end
