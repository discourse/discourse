# frozen_string_literal: true

module TopicQueryParams
  def build_topic_list_options
    options = {}
    params[:tags] = [params[:tag_id].parameterize] if params[:tag_id].present? && guardian.can_tag_pms?

    TopicQuery.public_valid_options.each do |key|
      if params.key?(key)
        val = options[key] = params[key]
        if !TopicQuery.validate?(key, val)
          raise Discourse::InvalidParameters.new key
        end
      end
    end

    # hacky columns get special handling
    options[:topic_ids] = param_to_integer_list(:topic_ids)
    if options[:no_subcategories] == 'true'
      options[:no_subcategories] = true
    end

    options
  end
end
