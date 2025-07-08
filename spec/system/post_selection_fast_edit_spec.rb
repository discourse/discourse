# frozen_string_literal: true

describe "Post selection | Fast edit", type: :system do
  let(:topic_page) { PageObjects::Pages::Topic.new }
  let(:fast_editor) { PageObjects::Components::FastEditor.new }

  fab!(:topic)

  fab!(:post) { Fabricate(:post, topic:) }
  fab!(:post_2) { Fabricate(:post, topic:, raw: "It ‘twas a great’ “time”!") }
  fab!(:spanish_post) { Fabricate(:post, topic:, raw: "Hola Juan, ¿cómo estás?") }
  fab!(:chinese_post) { Fabricate(:post, topic:, raw: "这是一个测试") }
  fab!(:post_with_emoji) { Fabricate(:post, topic:, raw: "Good morning :wave:!") }
  fab!(:post_with_quote) do
    Fabricate(
      :post,
      topic:,
      raw: "[quote]\n#{post_2.raw}\n[/quote]\n\nBelle journée, n'est-ce pas ?",
    )
  end

  fab!(:current_user) { Fabricate(:admin) }

  before { sign_in(current_user) }

  def css(post) = "#{topic_page.post_by_number_selector(post.post_number)} .cooked p"

  context "when text is selected" do
    before do
      topic_page.visit_topic(topic)
      select_text_range(css(post), 0, 5)
    end

    it "opens context menu" do
      expect(topic_page.fast_edit_button).to be_visible
    end

    context "when clicking the fast edit button" do
      before { topic_page.click_fast_edit_button }

      it "opens the fast editor" do
        expect(topic_page.fast_edit_input).to be_visible
      end

      context "when entering some text and clicking the save button" do
        before do
          fast_editor.fill_content("Howdy")
          fast_editor.save
        end

        it "saves changes" do
          expect(page).to have_selector(css(post), text: "Howdy world")
        end
      end
    end
  end

  context "when text selected is inside a quote" do
    it "opens the composer directly" do
      topic_page.visit_topic(topic)

      select_text_range(css(post_with_quote), 5, 10)
      topic_page.click_fast_edit_button

      expect(topic_page).to have_expanded_composer
    end
  end

  context "when editing text that has strange characters" do
    it "saves when paragraph contains apostrophes" do
      topic_page.visit_topic(topic)

      select_text_range(css(post_2), 19, 4)
      topic_page.click_fast_edit_button

      fast_editor.fill_content("day")
      fast_editor.save

      expect(page).to have_selector(css(post_2), text: "It ‘twas a great’ “day”!")
    end

    it "saves when text contains diacritics" do
      topic_page.visit_topic(topic)

      select_text_range(css(spanish_post), 11, 12)

      topic_page.click_fast_edit_button

      fast_editor.fill_content("¿está todo bien?")
      fast_editor.save

      expect(page).to have_selector(css(spanish_post), text: "Hola Juan, ¿está todo bien?")
    end

    it "saves when text contains CJK ranges" do
      topic_page.visit_topic(topic)

      select_text_range(css(chinese_post), 0, 2)
      topic_page.click_fast_edit_button

      fast_editor.fill_content("今天")
      fast_editor.save

      expect(page).to have_selector(css(chinese_post), text: "今天一个测试")
    end

    it "saves when text contains emoji" do
      topic_page.visit_topic(topic)

      select_text_range(css(post_with_emoji), 5, 7)
      topic_page.click_fast_edit_button

      fast_editor.fill_content("day")
      fast_editor.save

      # NOTE: the emoji isn't picked up by the "text:" selector
      expect(page).to have_selector(css(post_with_emoji), text: "Good day !")
      # So we also check the raw content to ensure it's been saved correctly
      expect(post_with_emoji.reload.raw).to eq "Good day :wave:!"
    end
  end
end
