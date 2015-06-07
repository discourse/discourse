module Jobs
  class PostAlert < Jobs::Base

    def execute(args)
      # maybe it was removed by the time we are making the post
      if post = Post.find_by(id: args[:post_id])
        # maybe the topic was deleted, so skip in that case as well
        PostAlerter.post_created(post) if post.topic
      end
    end

  end
end

