require_dependency 'queued_post_serializer'

class QueuedPostsController < ApplicationController

  before_action :ensure_staff

  def index
    state = QueuedPost.states[(params[:state] || 'new').to_sym]
    state ||= QueuedPost.states[:new]

    @queued_posts = QueuedPost.visible.where(state: state).includes(:topic, :user).order(:created_at)
    render_serialized(@queued_posts,
                      QueuedPostSerializer,
                      root: :queued_posts,
                      rest_serializer: true,
                      refresh_queued_posts: "/queued_posts?status=new")

  end

  def update
    qp = QueuedPost.where(id: params[:id]).first

    return render_json_error I18n.t('queue.not_found') if qp.blank?

    update_params = params[:queued_post]

    qp.raw = update_params[:raw] if update_params[:raw].present?
    if qp.topic_id.blank? && params[:queued_post][:state].blank?
      qp.post_options['title'] = update_params[:title] if update_params[:title].present?
      qp.post_options['category'] = update_params[:category_id].to_i if update_params[:category_id].present?
      qp.post_options['tags'] = update_params[:tags]
    end

    qp.save(validate: false)

    state = params[:queued_post][:state]
    begin
      if state == 'approved'
        qp.approve!(current_user)
      elsif state == 'rejected'
        qp.reject!(current_user)
        if params[:queued_post][:delete_user] == 'true' && guardian.can_delete_user?(qp.user)
          UserDestroyer.new(current_user).destroy(qp.user, user_deletion_opts)
        end
      end
    rescue StandardError => e
      return render_json_error e.message
    end

    render_serialized(qp, QueuedPostSerializer, root: :queued_posts)
  end

  private

  def user_deletion_opts
    base = {
      context: I18n.t('queue.delete_reason', performed_by: current_user.username),
      delete_posts: true,
      delete_as_spammer: true
    }

    if Rails.env.production? && ENV["Staging"].nil?
      base.merge!(block_email: true, block_ip: true)
    end

    base
  end

end
