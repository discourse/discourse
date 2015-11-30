class SiteTextSerializer < ApplicationSerializer
  attributes :id, :value, :overridden?, :can_revert?

  def id
    object[:id]
  end

  def value
    object[:value]
  end

  def overridden?
    current_val = value

    I18n.overrides_disabled do
      return I18n.t(object[:id]) != current_val
    end
  end

  alias_method :can_revert?, :overridden?
end

