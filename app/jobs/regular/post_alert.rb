module Jobs
  class PostAlert < Jobs::Base

    def execute(args)
      # maybe it was removed by the time we are making the post
      if post = Post.find_by(id: args[:post_id])
        PostAlerter.post_created(post)
      end
    end

  end
end

