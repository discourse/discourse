require_dependency 'queued_post_serializer'

class QueuedPostsController < ApplicationController

  before_filter :ensure_staff

  def index
    state = QueuedPost.states[(params[:state] || 'new').to_sym]
    state ||= QueuedPost.states[:new]

    @queued_posts = QueuedPost.where(state: state)
    render_serialized(@queued_posts, QueuedPostSerializer, root: :queued_posts)
  end

  def update
    qp = QueuedPost.where(id: params[:id]).first
    render_serialized(qp, QueuedPostSerializer, root: :queued_posts)
  end

end
