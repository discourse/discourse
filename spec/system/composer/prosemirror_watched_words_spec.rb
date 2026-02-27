# frozen_string_literal: true

describe "Composer - ProseMirror - Watched Words", type: :system do
  include_context "with prosemirror editor"

  context "with watched word replacements" do
    fab!(:topic) { Fabricate(:topic, user: current_user) }
    fab!(:post) do
      Fabricate(:post, topic:, user: current_user, raw: "We need to improve the ETA on this")
    end
    fab!(:watched_word) do
      Fabricate(
        :watched_word,
        action: WatchedWord.actions[:replace],
        word: "ETA",
        replacement: "Estimated Time of Arrival (ETA)",
      )
    end

    it "does not apply replacements to the raw content" do
      visit "/t/#{topic.slug}/#{topic.id}"
      find(".post-action-menu__edit").click
      expect(composer).to be_opened
      composer.focus

      expect(rich).to have_content("ETA")
      expect(rich).to have_no_content("Estimated Time of Arrival (ETA)")

      composer.toggle_rich_editor

      expect(composer).to have_value("We need to improve the ETA on this")
    end
  end

  context "with censored words" do
    fab!(:topic) { Fabricate(:topic, user: current_user) }
    fab!(:post) do
      Fabricate(:post, topic:, user: current_user, raw: "This is a badword in the post")
    end
    fab!(:watched_word) do
      Fabricate(:watched_word, action: WatchedWord.actions[:censor], word: "badword")
    end

    it "does not censor the raw content" do
      visit "/t/#{topic.slug}/#{topic.id}"
      find(".post-action-menu__edit").click
      expect(composer).to be_opened
      composer.focus

      expect(rich).to have_content("badword")

      composer.toggle_rich_editor

      expect(composer).to have_value("This is a badword in the post")
    end
  end
end
