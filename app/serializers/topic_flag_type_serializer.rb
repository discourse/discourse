class TopicFlagTypeSerializer < PostActionTypeSerializer

  protected

    def i18n(field, vars={})
      I18n.t("topic_flag_types.#{object.name_key}.#{field}", vars)
    end

end
