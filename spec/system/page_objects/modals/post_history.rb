# frozen_string_literal: true

module PageObjects
  module Modals
    class PostHistory < PageObjects::Modals::Base
      MODAL_SELECTOR = ".history-modal"

      def click_previous_revision
        footer.locator("button.previous-revision").filter(visible: true).click
        self
      end

      def previous_locale
        body.locator(".revision__locale .revision-content.--previous").filter(visible: true)
      end

      def current_locale
        body.locator(".revision__locale .revision-content.--current").filter(visible: true)
      end

      def current_revision
        revision_numbers.locator("strong:nth-child(3)").filter(visible: true)
      end

      def hide_revision
        footer.locator("button.hide-revision").filter(visible: true).click
        self
      end

      def destroy_revisions
        footer.locator("button.destroy-revision").filter(visible: true).click
      end

      def has_destroy_revisions_button?
        PlaywrightMatchers.have_count(0).does_not_match?(
          footer.locator("button.destroy-revision").filter(visible: true),
        )
      end

      def has_tag_changes?
        PlaywrightMatchers.have_count(0).does_not_match?(
          body.locator(".-tag-revisions").filter(visible: true),
        )
      end

      def has_hidden_diff_notice?
        PlaywrightMatchers.contain_text(
          [browser_text_pattern(I18n.t("js.post.revisions.diff_hidden"))],
          useInnerText: true,
        ).matches?(body.locator(".revision__hidden-notice").filter(visible: true))
      end

      def has_no_hidden_diff_notice?
        PlaywrightMatchers.have_count(0).matches?(
          body
            .tap do |parent|
              parent.wait_for(state: "visible", timeout: Capybara.default_max_wait_time * 1000)
            end
            .locator(".revision__hidden-notice")
            .filter(visible: true),
        )
      end

      def has_body_diff?(text)
        PlaywrightMatchers.contain_text([browser_text_pattern(text)], useInnerText: true).matches?(
          body.locator(".body-diff").filter(visible: true),
        )
      end

      def previous_tags
        body.locator(".-tag-revisions .tag-revision__wrapper:first-child").filter(visible: true)
      end

      def current_tags
        body.locator(".-tag-revisions .tag-revision__wrapper:last-child").filter(visible: true)
      end

      def deleted_tags
        body
          .locator(".-tag-revisions .discourse-tag.diff-del")
          .filter(visible: true)
          .tap { |elements| elements.first.wait_for(state: "visible") }
          .all
          .map { |element| element.inner_text.strip }
      end

      def inserted_tags
        body
          .locator(".-tag-revisions .discourse-tag.diff-ins")
          .filter(visible: true)
          .tap { |elements| elements.first.wait_for(state: "visible") }
          .all
          .map { |element| element.inner_text.strip }
      end

      private

      def revision_numbers
        footer.locator("#revision-numbers").filter(visible: true)
      end
    end
  end
end
