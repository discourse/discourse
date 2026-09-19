# frozen_string_literal: true

module PageObjects
  module Modals
    class ViewTranslationsModal < PageObjects::Modals::Base
      MODAL_SELECTOR = ".post-translations-modal"

      def select_post_language(language)
        within(full_modal_selector) do
          select(language, from: I18n.t("js.post.localizations.modal.post_language"))
        end
        self
      end

      def select_topic_language(language)
        within(full_modal_selector) do
          select(language, from: I18n.t("js.post.localizations.modal.topic_language"))
        end
        self
      end

      def save_post_language
        find("#{full_modal_selector} .post-translations-modal__post-language .--save").click
        self
      end

      def save_topic_language
        find("#{full_modal_selector} .post-translations-modal__topic-language .--save").click
        self
      end

      def has_post_language?(language)
        has_select?(I18n.t("js.post.localizations.modal.post_language"), selected: language)
      end

      def has_topic_language?(language)
        has_select?(I18n.t("js.post.localizations.modal.topic_language"), selected: language)
      end

      def has_language_notice?
        has_css?(
          "#{full_modal_selector} .post-translations-modal__post-language .form-kit__container-help-text",
          text: I18n.t("js.post.localizations.modal.language_notice"),
        )
      end

      def has_translation_language?(language)
        has_css?("#{full_modal_selector} .post-translations-modal__locale", text: language)
      end
    end
  end
end
