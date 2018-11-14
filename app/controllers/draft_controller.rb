class DraftController < ApplicationController
  requires_login

  skip_before_action :check_xhr, :preload_json

  def show
    seq = params[:sequence] || DraftSequence.current(current_user, params[:draft_key])
    render json: { draft: Draft.get(current_user, params[:draft_key], seq), draft_sequence: seq }
  end

  def update
    Draft.set(current_user, params[:draft_key], params[:sequence].to_i, params[:data])

    if data = JSON::parse(params[:data])
      if data["postId"].present? && data["originalText"].present?
        post = Post.find_by(id: data["postId"])
        if post && post.raw != data["originalText"]
          conflict_user = BasicUserSerializer.new(post.last_editor, root: false)
          return render json: success_json.merge(conflict_user: conflict_user)
        end
      end
    end

    render json: success_json
  end

  def destroy
    Draft.clear(current_user, params[:draft_key], params[:sequence].to_i)
    render json: success_json
  end

end
