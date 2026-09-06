# frozen_string_literal: true

module PageObjects
  module Modals
    class PostHistory < PageObjects::Modals::Base
      MODAL_SELECTOR = ".history-modal"

      def click_previous_revision
        footer.find("button.previous-revision").click
        self
      end

      def previous_locale
        body.find(".revision__locale .revision-content.--previous")
      end

      def current_locale
        body.find(".revision__locale .revision-content.--current")
      end

      def current_revision
        revision_numbers.find("strong:nth-child(3)")
      end

      def hide_revision
        footer.find("button.hide-revision").click
        self
      end

      def destroy_revisions
        footer.find("button.destroy-revision").click
      end

      def has_destroy_revisions_button?
        footer.has_css?("button.destroy-revision")
      end

      def has_tag_changes?
        body.has_css?(".-tag-revisions")
      end

      def has_hidden_diff_notice?
        body.has_css?(".revision__hidden-notice", text: I18n.t("js.post.revisions.diff_hidden"))
      end

      def has_no_hidden_diff_notice?
        body.has_no_css?(".revision__hidden-notice")
      end

      def has_body_diff?(text)
        body.has_css?(".body-diff", text: text)
      end

      def previous_tags
        body.find(".-tag-revisions .tag-revision__wrapper:first-child")
      end

      def current_tags
        body.find(".-tag-revisions .tag-revision__wrapper:last-child")
      end

      def deleted_tags
        body.all(".-tag-revisions .discourse-tag.diff-del").map(&:text)
      end

      def inserted_tags
        body.all(".-tag-revisions .discourse-tag.diff-ins").map(&:text)
      end

      private

      def revision_numbers
        footer.find("#revision-numbers")
      end
    end
  end
end
