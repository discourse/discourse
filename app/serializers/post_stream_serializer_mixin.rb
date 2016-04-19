require_dependency 'gap_serializer'
require_dependency 'post_serializer'

module PostStreamSerializerMixin

  def self.included(klass)
    klass.attributes :post_stream
  end

  def post_stream
    result = { posts: posts, stream: object.filtered_post_ids }
    result[:gaps] = GapSerializer.new(object.gaps, root: false) if object.gaps.present?
    result
  end

  def posts
    return @posts if @posts.present?
    @posts = []
    if object.posts
      object.posts.each do |p|
        ps = PostSerializer.new(p, scope: scope, root: false)
        ps.add_raw = true if @options[:include_raw]
        ps.topic_view = object
        p.topic = object.topic

        @posts << ps.as_json
      end
    end
    @posts
  end

end
