export default function () {
  this.route("post-voting-comment-permalink", {
    path: "/t/:slug/:topic_id/comment/:comment_id",
  });
}
