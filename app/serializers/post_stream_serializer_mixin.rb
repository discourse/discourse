# frozen_string_literal: true

module PostStreamSerializerMixin
  def self.included(klass)
    klass.attributes :post_stream
    klass.attributes :timeline_lookup
    klass.attributes :user_badges
  end

  def include_stream?
    true
  end

  def include_gaps?
    true
  end

  def include_user_badges?
    badges_to_include.present?
  end

  def user_badges
    object.user_badges(badges_to_include)
  end

  def badges_to_include
    @badges_to_include ||= theme_modifier_helper.serialize_post_user_badges
  end

  def post_stream
    result = { posts: posts }

    if include_stream?
      if !object.is_mega_topic?
        result[:stream] = object.filtered_post_ids
      else
        result[:isMegaTopic] = true
        result[:lastId] = object.last_post_id
      end
    end

    if include_gaps? && object.gaps.present?
      result[:gaps] = GapSerializer.new(object.gaps, root: false)
    end

    result
  end

  def include_timeline_lookup?
    !object.is_mega_topic?
  end

  def timeline_lookup
    TimelineLookup.build(object.filtered_post_stream)
  end

  def posts
    @posts ||=
      begin
        (object.posts || []).map do |post|
          post.topic = object.topic

          serializer = PostSerializer.new(post, scope: scope, root: false)
          serializer.add_raw = true if @options[:include_raw]
          serializer.topic_view = object

          serializer.as_json
        end
      end
  end

  def theme_modifier_helper
    @theme_modifier_helper ||= ThemeModifierHelper.new(request: scope.request)
  end
end
