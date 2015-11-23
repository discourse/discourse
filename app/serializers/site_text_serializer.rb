class SiteTextSerializer < ApplicationSerializer
  attributes :id, :value, :can_revert?

  def id
    object[:id]
  end

  def value
    object[:value]
  end

  def can_revert?
    current_val = value

    I18n.overrides_disabled do
      return I18n.t(object[:id]) != current_val
    end
  end
end

