class Lp::TopicsController < TopicsController
  POSTS_SINCE = 15.minutes.ago

  def index
    topic_ids = Post.
                public_posts.
                where("posts.created_at >= ?", POSTS_SINCE).
                select("topic_id").
                distinct.
                map{|p| p.topic_id}

    render json: MultiJson.dump(topic_ids)
  end
end
