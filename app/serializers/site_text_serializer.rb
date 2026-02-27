# frozen_string_literal: true

class SiteTextSerializer < ApplicationSerializer
  attributes :id,
             :value,
             :status,
             :old_default,
             :new_default,
             :interpolation_keys,
             :overridden?,
             :can_revert?

  def id
    object[:id]
  end

  def value
    object[:value]
  end

  def status
    if override.present?
      override.status
    else
      "up_to_date"
    end
  end

  def old_default
    override.original_translation if override.present?
  end

  def new_default
    override.current_default if override.present?
  end

  def interpolation_keys
    object[:interpolation_keys]
  end

  def overridden?
    if options[:overridden_keys]
      options[:overridden_keys].include?(object[:id])
    else
      override.present?
    end
  end

  alias_method :can_revert?, :overridden?

  private

  def override
    TranslationOverride.find_by(locale: object[:locale], translation_key: object[:id])
  end
end
