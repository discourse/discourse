# frozen_string_literal: true

class SiteTextSerializer < ApplicationSerializer
  attributes :id, :value, :overridden?, :can_revert?

  def id
    object[:id]
  end

  def value
    object[:value]
  end

  def overridden?
    if options[:overridden_keys]
      options[:overridden_keys].include?(object[:id])
    else
      TranslationOverride.exists?(locale: I18n.locale, translation_key: object[:id])
    end
  end

  alias_method :can_revert?, :overridden?
end
