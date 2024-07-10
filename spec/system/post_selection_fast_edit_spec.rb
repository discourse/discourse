# frozen_string_literal: true

describe "Post selection | Fast edit", type: :system do
  let(:topic_page) { PageObjects::Pages::Topic.new }
  let(:fast_editor) { PageObjects::Components::FastEditor.new }
  fab!(:topic)
  fab!(:post) { Fabricate(:post, topic: topic) }
  fab!(:post_2) { Fabricate(:post, topic: topic, raw: "It ‘twas a great’ “time”!") }
  fab!(:spanish_post) { Fabricate(:post, topic: topic, raw: "Hola Juan, ¿cómo estás?") }
  fab!(:chinese_post) { Fabricate(:post, topic: topic, raw: "这是一个测试") }
  fab!(:post_with_emoji) { Fabricate(:post, topic: topic, raw: "Good morning :wave:!") }
  fab!(:post_with_quote) do
    Fabricate(
      :post,
      topic: topic,
      raw: "[quote]\n#{post_2.raw}\n[/quote]\n\nBelle journée, n'est-ce pas ?",
    )
  end
  fab!(:current_user) { Fabricate(:admin) }

  before { sign_in(current_user) }

  context "when text selected it opens contact menu and fast editor" do
    it "opens context menu and fast edit dialog" do
      topic_page.visit_topic(topic)

      select_text_range("#{topic_page.post_by_number_selector(1)} .cooked p", 0, 10)
      expect(topic_page.fast_edit_button).to be_visible

      topic_page.click_fast_edit_button
      expect(topic_page.fast_edit_input).to be_visible
    end

    it "edits first paragraph and saves changes" do
      topic_page.visit_topic(topic)

      select_text_range("#{topic_page.post_by_number_selector(1)} .cooked p", 0, 5)
      topic_page.click_fast_edit_button

      fast_editor.fill_content("Howdy")
      fast_editor.save

      within("#post_1 .cooked > p") do |el|
        expect(el).not_to eq("Hello world")
        expect(el).to have_content("Howdy")
      end
    end
  end

  context "when text selected is inside a quote" do
    it "opens the composer directly" do
      topic_page.visit_topic(topic)

      select_text_range("#{topic_page.post_by_number_selector(6)} .cooked p", 5, 10)
      topic_page.click_fast_edit_button

      expect(topic_page).to have_expanded_composer
    end
  end

  context "when editing text that has strange characters" do
    it "saves when paragraph contains apostrophe" do
      topic_page.visit_topic(topic)

      select_text_range("#{topic_page.post_by_number_selector(2)} .cooked p", 19, 4)
      topic_page.click_fast_edit_button

      fast_editor.fill_content("day")
      fast_editor.save

      expect(page).to have_selector(
        "#{topic_page.post_by_number_selector(2)} .cooked p",
        text: "It ‘twas a great’ “day”!",
      )
    end

    it "saves when text contains diacratics" do
      topic_page.visit_topic(topic)

      select_text_range("#{topic_page.post_by_number_selector(3)} .cooked p", 11, 12)

      topic_page.click_fast_edit_button

      fast_editor.fill_content("¿está todo bien?")
      fast_editor.save

      expect(page).to have_selector(
        "#{topic_page.post_by_number_selector(3)} .cooked p",
        text: "Hola Juan, ¿está todo bien?",
      )
    end

    it "saves when text contains CJK ranges" do
      topic_page.visit_topic(topic)

      select_text_range("#{topic_page.post_by_number_selector(4)} .cooked p", 0, 2)
      topic_page.click_fast_edit_button

      fast_editor.fill_content("今天")
      fast_editor.save

      expect(page).to have_selector(
        "#{topic_page.post_by_number_selector(4)} .cooked p",
        text: "今天一个测试",
      )
    end

    it "saves when text contains emoji" do
      topic_page.visit_topic(topic)

      select_text_range("#{topic_page.post_by_number_selector(5)} .cooked p", 5, 7)
      topic_page.click_fast_edit_button

      fast_editor.fill_content("day")
      fast_editor.save

      expect(page).to have_no_css("#fast-edit-input")
      expect(post_with_emoji.raw).to eq("Good day :wave:!")
    end
  end
end
