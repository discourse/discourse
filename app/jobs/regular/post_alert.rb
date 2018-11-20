require_dependency 'post_alerter'

module Jobs
  class PostAlert < Jobs::Base

    def execute(args)
      post = Post.find_by(id: args[:post_id])
      if post&.topic
        opts = args[:options] || {}
        new_record = true == args[:new_record]
        PostAlerter.new(opts).after_save_post(post, new_record)
      end
    end

  end
end
