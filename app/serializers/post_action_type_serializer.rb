require_dependency 'configurable_urls'

class PostActionTypeSerializer < ApplicationSerializer

  attributes(
    :id,
    :name_key,
    :name,
    :description,
    :short_description,
    :long_form,
    :is_flag,
    :is_custom_flag
  )

  include ConfigurableUrls

  def is_custom_flag
    !!PostActionType.custom_types[object.id]
  end

  def is_flag
    !!PostActionType.flag_types[object.id]
  end

  def name
    i18n('title')
  end

  def long_form
    i18n('long_form')
  end

  def description
    i18n('description', tos_url: tos_path)
  end

  def short_description
    i18n('short_description', tos_url: tos_path)
  end

  def name_key
    PostActionType.types[object.id]
  end

  protected

  def i18n(field, vars = nil)
    key = "post_action_types.#{name_key}.#{field}"
    vars ? I18n.t(key, vars) : I18n.t(key)
  end

end
