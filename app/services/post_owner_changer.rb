class PostOwnerChanger

  def initialize(params)
    @post_ids = params[:post_ids]
    @topic = Topic.find_by(id: params[:topic_id].to_i)
    @new_owner = params[:new_owner]
    @acting_user = params[:acting_user]

    raise ArgumentError unless @post_ids && @topic && @new_owner && @acting_user
  end

  def change_owner!
    ActiveRecord::Base.transaction do
      @post_ids.each do |post_id|
        post = Post.find(post_id)
        @topic.user = @new_owner if post.is_first_post?
        post.set_owner(@new_owner, @acting_user)
      end

      @topic.update_statistics
      @new_owner.user_stat.update(first_post_created_at: @new_owner.posts(true).order('created_at ASC').first.try(:created_at))
    end
  end
end
