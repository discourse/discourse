# frozen_string_literal: true

class TopicFlagTypeSerializer < PostActionTypeSerializer

  protected

  def i18n(field, vars = nil)
    key = "topic_flag_types.#{name_key}.#{field}"
    vars ? I18n.t(key, vars) : I18n.t(key)
  end

end
