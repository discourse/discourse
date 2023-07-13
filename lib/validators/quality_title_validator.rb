# frozen_string_literal: true

require "text_sentinel"
require "text_cleaner"

class QualityTitleValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    return if Discourse.static_doc_topic_ids.include?(record.id) && record.acting_user&.admin?

    sentinel = TextSentinel.title_sentinel(value)

    if !sentinel.valid?
      if !sentinel.seems_meaningful?
        record.errors.add(attribute, :is_invalid_meaningful)
      elsif !sentinel.seems_unpretentious?
        record.errors.add(attribute, :is_invalid_unpretentious)
      elsif !sentinel.seems_quiet?
        record.errors.add(attribute, :is_invalid_quiet)
      else
        record.errors.add(attribute, :is_invalid)
      end
    end
  end
end
