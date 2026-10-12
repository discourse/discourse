# frozen_string_literal: true

module PostRevisionParams
  include TagParamLimit

  private

  def prepare_post_revision_params(revision)
    attributes = permitted_post_revision_attributes(revision)
    reject_too_many_tags!(:tags, :original_tags, parameters: revision)

    attributes
  end

  def post_revision_params
    post = params.require(:post)
    input = post.slice(:original_text, :reply_to_post_number, :category_id, :bypass_bump)

    input.merge!(raw: post[:raw], edit_reason: post[:edit_reason], locale: post[:locale])
    Post.plugin_permitted_update_params.keys.each { |param| input[param] = post[param] }

    # keep `raw_old` for backwards compatibility
    input[:original_text] ||= post[:raw_old]
    input[:title] = params[:title] if params[:title]
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

    { topic_id: params[:topic_id], changes: permitted_post_revision_attributes(input) }
  end

  def permitted_post_revision_attributes(parameters)
    unless parameters.is_a?(ActionController::Parameters)
      raise Discourse::InvalidParameters.new(:post_revision)
    end

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
          image_sizes: {
          },
        )
        .to_h
        .deep_symbolize_keys

    %i[tags original_tags].each do |key|
      next unless parameters.key?(key)

      tags = parameters[key]
      tags = nil if key == :tags && tags == ""

      permitted[key] = if tags.is_a?(Array)
        tags.map do |tag|
          tag.is_a?(ActionController::Parameters) ? tag.permit(:id, :name).to_h : tag
        end
      else
        tags
      end
    end

    permitted.deep_symbolize_keys!

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
