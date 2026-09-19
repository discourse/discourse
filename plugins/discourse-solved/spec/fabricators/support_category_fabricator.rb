# frozen_string_literal: true
Fabricator(:support_category, from: :category) do
  after_create do |category|
    category.custom_fields[DiscourseSolved::ENABLE_ACCEPTED_ANSWERS_CUSTOM_FIELD] = "true"
    category.save!
  end
end
