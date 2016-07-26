#
# This class contains the logic to merge two or more posts by the same user
#
class PostMerger

  def initialize(user, posts)
    @user = user
    @posts = posts
  end

  def merge
    postContent = []

    @posts.each { |p| postContent.push(p.raw) }

    post = @posts.last
    changes = {
      raw: postContent.join("\n\n"),
      edit_reason: "Merged #{@posts.length} posts by #{@user.name}"
    }

    Post.transaction do
      revisor = PostRevisor.new(post, post.topic)
      revisor.revise!(@user, changes, {})
      @posts.each_with_index  do |p, index|
        # do not delete the last post since it will have the content of the merged posts
        if index < @posts.length - 1
          PostDestroyer.new(@user, p).destroy
        end
      end
    end
  end

end
