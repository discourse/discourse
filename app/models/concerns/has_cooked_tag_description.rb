# frozen_string_literal: true

module HasCookedTagDescription
  extend ActiveSupport::Concern

  BAKED_VERSION = 1
  COOK_OPTIONS = { features: { onebox: false } }.freeze

  def cook_description
    return unless description_changed?

    self.description_cooked = cook_description_html
    self.description_cooked_version = BAKED_VERSION
  end

  def rebake!
    update_columns(
      description_cooked: cook_description_html,
      description_cooked_version: BAKED_VERSION,
    )
  end

  private

  def cook_description_html
    description.present? ? PrettyText.cook(description, COOK_OPTIONS) : nil
  end

  class_methods do
    def rebake_old(limit)
      problems = []

      where(
        "description_cooked_version IS NULL OR description_cooked_version < ?",
        HasCookedTagDescription::BAKED_VERSION,
      )
        .limit(limit)
        .each do |record|
          record.rebake!
        rescue => e
          problems << { record: record, ex: e }
        end

      problems
    end
  end
end
