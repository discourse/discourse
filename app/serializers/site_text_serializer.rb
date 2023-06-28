# frozen_string_literal: true

class SiteTextSerializer < ApplicationSerializer
  attributes :id, :value, :interpolation_keys, :has_interpolation_keys?, :overridden?, :can_revert?

  def id
    object[:id]
  end

  def value
    object[:value]
  end

  def interpolation_keys
    object[:interpolation_keys]
  end

  def has_interpolation_keys?
    object[:interpolation_keys].present?
  end

  def overridden?
    if options[:overridden_keys]
      options[:overridden_keys].include?(object[:id])
    else
      TranslationOverride.exists?(locale: object[:locale], translation_key: object[:id])
    end
  end

  alias_method :can_revert?, :overridden?
end
