# frozen_string_literal: true

describe "Fast edit", type: :system, js: true do
  let(:topic_page) { PageObjects::Pages::Topic.new }
  let(:fast_editor) { PageObjects::Components::FastEditor.new }
  fab!(:topic) { Fabricate(:topic) }
  fab!(:post) { Fabricate(:post, topic: topic) }
  fab!(:post_2) { Fabricate(:post, topic: topic, raw: "It 'twas a great time!") }
  fab!(:current_user) { Fabricate(:admin) }

  before do
    current_user.activate
    sign_in(current_user)
  end

  context "when text selected it opens contact menu and fast editor" do
    it "opens context menu and fast edit dialog" do
      topic_page.visit_topic(topic)

      topic_page.select_text("#post_1 .cooked > p", 10)
      expect(topic_page.fast_edit_button).to be_visible

      topic_page.click_fast_edit_button
      expect(topic_page.fast_edit_input).to be_visible
    end

    it "edits first paragraph and saves changes" do
      topic_page.visit_topic(topic)

      topic_page.select_text("#post_1 .cooked > p", 5)
      topic_page.click_fast_edit_button

      fast_editor.fill_content("Howdy")
      fast_editor.save

      within("#post_1 .cooked > p") do |el|
        expect(el).not_to eq("Hello world")
        expect(el).to have_content("Howdy")
      end
    end
  end

  context "when editing text that has strange characters" do
    it "saves when paragraph contains apostrophe" do
      topic_page.visit_topic(topic)

      topic_page.select_text("#post_2 .cooked > p", 8)
      topic_page.click_fast_edit_button

      fast_editor.fill_content("It was")
      fast_editor.save

      expect(find("#post_2 .cooked > p")).to have_content("It was a great time!")
    end
  end
end
