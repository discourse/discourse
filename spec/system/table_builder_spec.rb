# frozen_string_literal: true

describe "Table Builder", type: :system do
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

  %w[enabled disabled].each do |value|
    before { SiteSetting.glimmer_post_stream_mode = value }

    context "when glimmer_post_stream_mode=#{value}" do
      context "when creating a new table" do
        it "should add table items created in spreadsheet to composer input" do
          visit("/latest")
          page.find("#create-topic").click
          find(".toolbar-menu__options-trigger").click
          page.find("button[data-name='toggle-spreadsheet']").click
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

          expect(normalize_value(composer.composer_input.value)).to eq(
            normalize_value(created_table),
          )
        end

        context "when cancelling table creation" do
          it "should close the modal if there are no changes made" do
            visit("/latest")
            page.find("#create-topic").click
            find(".toolbar-menu__options-trigger").click
            page.find("button[data-name='toggle-spreadsheet']").click
            insert_table_modal.cancel
            expect(page).to have_no_css(".insert-table-modal")
          end

          it "should show a warning popup if there are unsaved changes" do
            visit("/latest")
            page.find("#create-topic").click
            find(".toolbar-menu__options-trigger").click
            page.find("button[data-name='toggle-spreadsheet']").click
            insert_table_modal.type_in_cell(0, 0, "Item 1")
            insert_table_modal.cancel
            expect(page).to have_css(".dialog-container .dialog-content")
          end
        end
      end

      context "when editing a table" do
        it "should prefill the spreadsheet with the markdown table items from the post" do
          topic_page.visit_topic(topic)
          topic_page.find(".btn-edit-table", visible: :all).click
          expect(page).to have_selector(".insert-table-modal")

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

        it "should update the post with the new table content" do
          topic_page.visit_topic(topic)
          topic_page.find(".btn-edit-table", visible: :all).click
          expect(page).to have_selector(".insert-table-modal")
          insert_table_modal.type_in_cell(1, 1, " GTR")
          insert_table_modal.click_insert_table

          updated_post = <<~RAW
            |Make | Model | Year|
            |--- | --- | ---|
            |Toyota | Supra | 1998|
            |Nissan | Skyline GTR | 1999|
            |Honda | S2000 | 2001|
          RAW

          try_until_success do
            expect(normalize_value(post1.reload.raw)).to eq(normalize_value(updated_post))
          end
        end

        it "should respect the original empty header" do
          topic_page.visit_topic(topic2)
          topic_page.find(".btn-edit-table", visible: :all).click
          expect(page).to have_selector(".insert-table-modal")
          insert_table_modal.type_in_cell(0, 0, " updated")
          insert_table_modal.click_insert_table

          updated_post = <<~RAW
            | |  | |
            |--- | --- | ---|
            |Some updated | content | here|
            |1 | 2 | 3|
          RAW

          try_until_success do
            expect(normalize_value(post2.reload.raw)).to eq(normalize_value(updated_post))
          end
        end

        context "when adding an edit reason" do
          it "should add the edit reason to the edit history" do
            edit_reason = "Updated Nissan model"

            topic_page.visit_topic(topic)
            topic_page.find(".btn-edit-table", visible: :all).click
            expect(page).to have_selector(".insert-table-modal")
            insert_table_modal.type_in_cell(1, 1, " GTR")
            insert_table_modal.click_edit_reason
            insert_table_modal.type_edit_reason(edit_reason)
            insert_table_modal.click_insert_table
            wait_for { post1.reload.edit_reason == edit_reason }
            expect(post1.reload.edit_reason).to eq(edit_reason)
          end
        end

        context "when cancelling table creation" do
          it "should close the modal if there are no changes made" do
            topic_page.visit_topic(topic)
            topic_page.find(".btn-edit-table", visible: :all).click
            expect(page).to have_selector(".insert-table-modal")
            insert_table_modal.cancel
            expect(page).to have_no_css(".insert-table-modal")
          end

          it "should show a warning popup if there are unsaved changes" do
            topic_page.visit_topic(topic)
            topic_page.find(".btn-edit-table", visible: :all).click
            expect(page).to have_selector(".insert-table-modal")
            insert_table_modal.type_in_cell(1, 1, " GTR")
            insert_table_modal.cancel
            expect(page).to have_css(".dialog-container .dialog-content")
          end
        end

        it "should not accept default Discourse keyboard shortcuts" do
          # Some default keyboard shortcuts like Shift + S bring up a modal overriding
          # the table builder modal and therefore should not be accepted

          topic_page.visit_topic(topic)
          topic_page.find(".btn-edit-table", visible: :all).click
          insert_table_modal.find_cell(0, 0)
          insert_table_modal.send_keys(:shift, "s")
          expect(page).to have_css(".insert-table-modal")
          expect(page).to have_no_css(".share-topic-modal")
        end
      end
    end
  end
end
