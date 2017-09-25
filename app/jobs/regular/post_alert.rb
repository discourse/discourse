require_dependency 'post_alerter'

module Jobs
  class PostAlert < Jobs::Base

    def execute(args)
      # maybe it was removed by the time we are making the post
      post = Post.where(id: args[:post_id]).first
      PostAlerter.post_created(post, args[:options] || {}) if post && post.topic
    end

  end
end
