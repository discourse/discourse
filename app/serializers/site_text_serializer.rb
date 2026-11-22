# frozen_string_literal: true

class SiteTextSerializer < ApplicationSerializer
  attributes :id,
             :value,
             :override_value,
             :preview_default,
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

  def override_value
    override&.value
  end

  def preview_default
    I18n.overrides_disabled { I18n.t(object[:id], locale: override.locale) }
  end

  def include_preview_default?
    options[:include_preview_default] && override.present?
  end

  def status
    if override.present?
      override.status
    else
      "up_to_date"
    end
  end

  def old_default
    override.presence&.original_translation
  end

  def new_default
    override.presence&.current_default
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
    return @override if defined?(@override)

    @override = TranslationOverride.find_by(locale: object[:locale], translation_key: object[:id])
  end
end
