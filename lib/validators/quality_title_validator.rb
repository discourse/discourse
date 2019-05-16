# frozen_string_literal: true

require 'text_sentinel'
require 'text_cleaner'

class QualityTitleValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    sentinel = TextSentinel.title_sentinel(value)
    record.errors.add(attribute, :is_invalid) unless sentinel.valid?
  end
end
