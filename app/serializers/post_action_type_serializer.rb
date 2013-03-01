class PostActionTypeSerializer < ApplicationSerializer

  attributes :name_key, :name, :description, :long_form, :is_flag, :icon, :id, :is_custom_flag

  def is_custom_flag
    object.id == PostActionType.types[:custom_flag]
  end

  def name
    i18n('title')
  end

  def long_form
    i18n('long_form')
  end

  def description
    i18n('description')
  end

  protected

    def i18n(field)
      I18n.t("post_action_types.#{object.name_key}.#{field}")
    end

end
