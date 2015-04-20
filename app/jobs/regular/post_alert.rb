module Jobs
  class PostAlert < Jobs::Base

    def execute(args)
      post = Post.find(args[:post_id])
      PostAlerter.post_created(post)
    end

  end
end

