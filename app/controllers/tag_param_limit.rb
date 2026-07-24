# frozen_string_literal: true

module TagParamLimit
  private

  def reject_too_many_tags!(*param_names)
    param_names.each do |param_name|
      next if !params.has_key?(param_name)
      next if tag_param_count(params[param_name]) <= SiteSetting.max_tags_per_topic

      render_json_error(
        I18n.t("tags.too_many_tags_for_topic", count: SiteSetting.max_tags_per_topic),
      )
      return true
    end

    false
  end

  def tag_param_count(tags)
    return tags.length if tags.is_a?(Array)
    return tags.keys.length if tags.is_a?(ActionController::Parameters)

    0
  end
end
