require_dependency 'queued_post_serializer'

class QueuedPostsController < ApplicationController

  before_filter :ensure_staff

  def index
    state = QueuedPost.states[(params[:state] || 'new').to_sym]
    state ||= QueuedPost.states[:new]

    @queued_posts = QueuedPost.visible.where(state: state).includes(:topic, :user)
    render_serialized(@queued_posts, QueuedPostSerializer, root: :queued_posts, rest_serializer: true)
  end

  def update
    qp = QueuedPost.where(id: params[:id]).first

    if params[:queued_post][:raw].present?
      qp.update_column(:raw, params[:queued_post][:raw])
    end

    state = params[:queued_post][:state]
    if state == 'approved'
      qp.approve!(current_user)
    elsif state == 'rejected'
      qp.reject!(current_user)
    end

    render_serialized(qp, QueuedPostSerializer, root: :queued_posts)
  end

end
