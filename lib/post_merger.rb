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
    @posts.each {|p| postContent.push(p.raw) }

    post = @posts.last
    changes = {
      raw: postContent.join("\n\n"),
      edit_reason: "Merged #{@posts.length} posts by #{@posts.first.user.name}"
    }
    revisor = PostRevisor.new(post, post.topic)
    revisor.revise!(@user, changes, {})
  end

end
