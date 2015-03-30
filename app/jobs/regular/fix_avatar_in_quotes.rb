module Jobs
  class FixAvatarInQuotes < Jobs::Base

    def execute(args)
      user = User.find(args[:user_id])
      post_ids_to_rebake = Post.exec_sql("SELECT post_id FROM quoted_posts WHERE quoted_post_id IN (SELECT id FROM posts WHERE user_id = ?)", user.id).values.flatten.map(&:to_i)
      Post.where(id: post_ids_to_rebake).find_each.map(&:rebake!)
    end

  end
end
