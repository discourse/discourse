# frozen_string_literal: true

module ::Blog
  # Editorial services run this before touching drafts, so a drafts category an
  # admin opened up is made private again on its next use.
  module DraftsCategoryStep
    private

    def ensure_drafts_category
      Blog::EnsureDraftsCategory.call do
        on_model_errors(:category) { |category| fail!(category.errors.full_messages.to_sentence) }
        on_model_not_found(:category) { |result| raise result.exception if result.exception }
        on_failure { fail!(I18n.t("blog.errors.drafts_category_unavailable")) }
      end
    end
  end
end
