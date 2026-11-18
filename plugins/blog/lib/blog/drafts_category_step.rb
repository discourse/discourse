# frozen_string_literal: true

module ::Blog
  # Editorial services run this before touching drafts, so groups an admin added
  # to the drafts category are removed on its next use.
  module DraftsCategoryStep
    private

    def ensure_drafts_category
      Blog::EnsureDraftsCategory.call do
        on_model_errors(:category) { |category| fail!(category.errors.full_messages.to_sentence) }
        on_model_not_found(:category) { |result| raise result.exception if result.exception }
        on_failed_policy(:category_private) { fail!(I18n.t("blog.errors.drafts_category_public")) }
        on_failure { fail!(I18n.t("blog.errors.drafts_category_unavailable")) }
      end
    end
  end
end
