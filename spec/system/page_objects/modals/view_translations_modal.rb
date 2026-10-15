# frozen_string_literal: true

module PageObjects
  module Modals
    class ViewTranslationsModal < PageObjects::Modals::Base
      MODAL_SELECTOR = ".post-translations-modal"

      def select_post_language(language)
        within_browser(full_modal_selector) do
          browser_root.get_by_label(
            I18n.t("js.post.localizations.modal.post_language"),
            exact: true,
          ).select_option(label: language)
        end
        self
      end

      def select_topic_language(language)
        within_browser(full_modal_selector) do
          browser_root.get_by_label(
            I18n.t("js.post.localizations.modal.topic_language"),
            exact: true,
          ).select_option(label: language)
        end
        self
      end

      def save_post_language
        browser_root
          .locator("#{full_modal_selector} .post-translations-modal__post-language .--save")
          .filter(visible: true)
          .click
        self
      end

      def save_topic_language
        browser_root
          .locator("#{full_modal_selector} .post-translations-modal__topic-language .--save")
          .filter(visible: true)
          .click
        self
      end

      def has_post_language?(language)
        PlaywrightMatchers.have_text(language).matches?(
          browser_root
            .locator("input:not(:disabled), textarea:not(:disabled), select:not(:disabled)")
            .and(
              browser_root.locator(
                "[id=#{I18n.t("js.post.localizations.modal.post_language").to_s.to_json}], [name=#{I18n.t("js.post.localizations.modal.post_language").to_s.to_json}]",
              ).or(
                browser_root.get_by_label(
                  I18n.t("js.post.localizations.modal.post_language"),
                  exact: true,
                ),
              ),
            )
            .filter(visible: true)
            .and(browser_root.locator("select"))
            .locator("option:checked"),
        )
      end

      def has_topic_language?(language)
        PlaywrightMatchers.have_text(language).matches?(
          browser_root
            .locator("input:not(:disabled), textarea:not(:disabled), select:not(:disabled)")
            .and(
              browser_root.locator(
                "[id=#{I18n.t("js.post.localizations.modal.topic_language").to_s.to_json}], [name=#{I18n.t("js.post.localizations.modal.topic_language").to_s.to_json}]",
              ).or(
                browser_root.get_by_label(
                  I18n.t("js.post.localizations.modal.topic_language"),
                  exact: true,
                ),
              ),
            )
            .filter(visible: true)
            .and(browser_root.locator("select"))
            .locator("option:checked"),
        )
      end

      def has_language_notice?
        PlaywrightMatchers.contain_text(
          [browser_text_pattern(I18n.t("js.post.localizations.modal.language_notice"))],
          useInnerText: true,
        ).matches?(
          browser_root.locator(
            "#{full_modal_selector} .post-translations-modal__post-language .form-kit__container-help-text",
          ).filter(visible: true),
        )
      end

      def has_translation_language?(language)
        PlaywrightMatchers.contain_text(
          [browser_text_pattern(language)],
          useInnerText: true,
        ).matches?(
          browser_root.locator("#{full_modal_selector} .post-translations-modal__locale").filter(
            visible: true,
          ),
        )
      end
    end
  end
end
