# frozen_string_literal: true

module PostStreamSerializerMixin
  def self.included(klass)
    klass.attributes :post_stream
    klass.attributes :timeline_lookup
  end

  def include_stream?
    true
  end

  def include_gaps?
    true
  end

  def post_stream
    result = { posts: posts }

    if include_stream?
      if !object.is_mega_topic?
        result[:stream] = object.filtered_post_ids
      else
        result[:isMegaTopic] = true
        result[:firstId] = object.first_post_id
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
    @posts ||= begin
      (object.posts || []).map do |post|
        post.topic = object.topic

        serializer = PostSerializer.new(post, scope: scope, root: false)
        serializer.add_raw = true if @options[:include_raw]
        serializer.topic_view = object

        serializer.as_json
      end
    end
  end

end
