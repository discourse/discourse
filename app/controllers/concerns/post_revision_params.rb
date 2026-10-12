# frozen_string_literal: true

module PostRevisionParams
  private

  def post_revision_params
    post = params.require(:post)
    input =
      post.slice(
        :raw,
        :original_text,
        :edit_reason,
        :locale,
        :reply_to_post_number,
        :category_id,
        :bypass_bump,
        *Post.plugin_permitted_update_params.keys,
      )
    input[:original_text] ||= post[:raw_old]
    input[:title] = params[:title] if params.key?(:title)
    input[:image_sizes] = params[:image_sizes] if params.key?(:image_sizes)
    input[:bypass_bump] = params[:bypass_bump] if params.key?(:bypass_bump)
    { post_id: params[:id], changes: permitted_post_revision_attributes(input) }
  end

  def topic_revision_params
    input =
      params.slice(
        *PostRevisor.tracked_topic_fields.keys,
        :original_title,
        :original_tags,
        :keep_existing_draft,
      )
    {
      topic_id: params[:topic_id],
      changes: permitted_post_revision_attributes(input, allow_tag_names: true),
    }
  end

  def permitted_post_revision_attributes(parameters, allow_tag_names: false)
    unless parameters.is_a?(ActionController::Parameters)
      raise Discourse::InvalidParameters.new(:edit)
    end

    %i[tags original_tags].each do |key|
      tags = parameters[key]
      next if tags.nil?
      valid =
        tags.is_a?(Array) &&
          tags.all? do |tag|
            next true if allow_tag_names && tag.is_a?(String)
            tag.is_a?(ActionController::Parameters) &&
              (
                tag[:id].nil? || (tag[:id].is_a?(Integer) && tag[:id].positive?) ||
                  (tag[:id].is_a?(String) && tag[:id].match?(/\A[1-9]\d*\z/))
              ) && (tag[:name].nil? || tag[:name].is_a?(String)) &&
              (tag[:id].present? || tag[:name].present?)
          end
      raise Discourse::InvalidParameters.new(key) unless valid
    end
    string_tags =
      parameters[:tags].is_a?(Array) && parameters[:tags].all? { |tag| tag.is_a?(String) }
    permitted =
      parameters
        .permit(
          :raw,
          :original_text,
          :edit_reason,
          :locale,
          :title,
          :original_title,
          :category_id,
          :featured_link,
          :archetype,
          :reply_to_post_number,
          :bypass_bump,
          :keep_existing_draft,
          tags: %i[id name],
          original_tags: %i[id name],
          image_sizes: {
          },
        )
        .to_h
        .deep_symbolize_keys
    permitted[:tags] = parameters[:tags] if string_tags
    if allow_tag_names && parameters[:original_tags].is_a?(Array) &&
         parameters[:original_tags].all? { |tag| tag.is_a?(String) }
      permitted[:original_tags] = parameters[:original_tags]
    end
    permitted.merge!(
      parameters
        .slice(*Post.plugin_permitted_update_params.keys, *PostRevisor.tracked_topic_fields.keys)
        .except(:title, :category_id, :tags, :featured_link, :archetype)
        .permit!
        .to_h
        .deep_symbolize_keys,
    )
  end
end
