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
      # this is a bit of a kludge we need to remove (all the parsing) too many special cases here
      # we need to catch action edit and action editSharedDraft
      if data["postId"].present? && data["originalText"].present? && data["action"].to_s.start_with?("edit")
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
