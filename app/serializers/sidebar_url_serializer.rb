# frozen_string_literal: true

class SidebarUrlSerializer < ApplicationSerializer
  attributes :id, :name, :value, :icon, :external, :segment, :locale, :can_localize

  has_many :localizations, embed: :objects, serializer: SidebarUrlLocalizationSerializer

  def name
    if @options[:show_translated_name] &&
         ContentLocalization.show_translated_sidebar_url?(object, scope)
      object.get_localization&.name || object.name
    else
      object.name
    end
  end

  def external
    object.external?
  end

  def include_localizations?
    @options[:include_localizations]
  end

  def can_localize
    @options[:can_localize]
  end

  def include_can_localize?
    @options.key?(:can_localize)
  end
end
