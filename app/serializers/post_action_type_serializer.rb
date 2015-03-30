require_dependency 'configurable_urls'

class PostActionTypeSerializer < ApplicationSerializer

  attributes :name_key, :name, :description, :long_form, :is_flag, :icon, :id, :is_custom_flag

  include ConfigurableUrls

  def is_custom_flag
    object.id == PostActionType.types[:notify_user] ||
    object.id == PostActionType.types[:notify_moderators] 
  end

  def name
    i18n('title')
  end

  def long_form
    i18n('long_form')
  end

  def description
    i18n('description', {tos_url: tos_path})
  end

  protected

    def i18n(field, vars=nil)
      key = "post_action_types.#{object.name_key}.#{field}"
      vars ? I18n.t(key, vars) : I18n.t(key)
    end

end
