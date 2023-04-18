# frozen_string_literal: true

module TopicQueryParams
  def build_topic_list_options
    options = {}
    params[:tags] = [params[:tag_id], *Array(params[:tags])].uniq if params[:tag_id].present?

    TopicQuery.public_valid_options.each do |key|
      if params.key?(key)
        val = options[key] = params[key]
        raise Discourse::InvalidParameters.new key if !TopicQuery.validate?(key, val)
      end
    end

    # hacky columns get special handling
    options[:topic_ids] = param_to_integer_list(:topic_ids)
    options[:no_subcategories] = options[:no_subcategories] == "true" if options[
      :no_subcategories
    ].present?

    if hide_welcome_topic?
      options[:except_topic_ids] ||= []
      options[:except_topic_ids] << SiteSetting.welcome_topic_id
    end

    options
  end

  private

  def hide_welcome_topic?
    return false if !SiteSetting.bootstrap_mode_enabled
    Site.welcome_topic_exists_and_is_not_edited?
  end
end
