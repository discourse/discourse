# frozen_string_literal: true

module PostVoting
  module CategoryExtension
    # `save_custom_fields` writes rows with raw SQL, so no ActiveRecord
    # callbacks fire on the category form's save path. This hook runs on both
    # that path and `upsert_custom_fields`.
    def on_custom_fields_change
      super

      PostVoting.clear_category_overrides_cache

      return if !custom_fields.key?(PostVoting::APPLY_TO_SUBCATEGORIES)

      apply = ActiveModel::Type::Boolean.new.cast(custom_fields[PostVoting::APPLY_TO_SUBCATEGORIES])

      # Discarded either way: it is an answer to one save, not a stored setting.
      custom_fields.delete(PostVoting::APPLY_TO_SUBCATEGORIES)
      PostVoting.discard_apply_to_subcategories_flag(id)
      PostVoting.apply_to_subcategories!(id) if apply
    end
  end
end
