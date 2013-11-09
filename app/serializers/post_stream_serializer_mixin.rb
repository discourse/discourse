module PostStreamSerializerMixin

  def self.included(klass)
    klass.attributes :post_stream
  end

  def post_stream
    { posts: posts,
      stream: object.filtered_post_ids }
  end

  def posts
    return @posts if @posts.present?
    @posts = []
    @highest_number_in_posts = 0
    if object.posts
      object.posts.each_with_index do |p, idx|
        @highest_number_in_posts = p.post_number if p.post_number > @highest_number_in_posts
        ps = PostSerializer.new(p, scope: scope, root: false)
        ps.topic_slug = object.topic.slug
        ps.topic_view = object
        p.topic = object.topic

        @posts << ps.as_json
      end
    end
    @posts
  end

end
