class TopicFlagTypeSerializer < PostActionTypeSerializer

  protected

    def i18n(field, vars=nil)
      key = "topic_flag_types.#{object.name_key}.#{field}"
      vars ? I18n.t(key,vars) : I18n.t(key)
    end

end
