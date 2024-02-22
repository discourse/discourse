# frozen_string_literal: true

module CustomField
  extend ActiveSupport::Concern

  class_methods do
    def true_fields
      where(value: HasCustomFields::Helpers::CUSTOM_FIELD_TRUE)
    end
  end
end
