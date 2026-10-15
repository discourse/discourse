# frozen_string_literal: true

describe "Composer - ProseMirror - Watched Words" do
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
      browser_page
        .goto("/t/#{topic.slug}/#{topic.id}")
        .tap { SystemBrowserBootstrap.wait_for(browser_page) }
      browser_root.locator(".post-action-menu__edit").filter(visible: true).click
      expect(composer).to be_opened
      composer.focus

      expect(rich).to PlaywrightMatchers.contain_text(
        browser_text_pattern("ETA"),
        useInnerText: true,
      )
      expect(
        rich.tap do |parent|
          parent.wait_for(state: "visible", timeout: Capybara.default_max_wait_time * 1000)
        end,
      ).not_to PlaywrightMatchers.contain_text(
        browser_text_pattern("Estimated Time of Arrival (ETA)"),
        useInnerText: true,
      )

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
      browser_page
        .goto("/t/#{topic.slug}/#{topic.id}")
        .tap { SystemBrowserBootstrap.wait_for(browser_page) }
      browser_root.locator(".post-action-menu__edit").filter(visible: true).click
      expect(composer).to be_opened
      composer.focus

      expect(rich).to PlaywrightMatchers.contain_text(
        browser_text_pattern("badword"),
        useInnerText: true,
      )

      composer.toggle_rich_editor

      expect(composer).to have_value("This is a badword in the post")
    end
  end
end
