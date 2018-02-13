class DraftController < ApplicationController
  requires_login

  skip_before_action :check_xhr, :preload_json

  def show
    seq = params[:sequence] || DraftSequence.current(current_user, params[:draft_key])
    render json: { draft: Draft.get(current_user, params[:draft_key], seq), draft_sequence: seq }
  end

  def update
    Draft.set(current_user, params[:draft_key], params[:sequence].to_i, params[:data])
    render json: success_json
  end

  def destroy
    Draft.clear(current_user, params[:draft_key], params[:sequence].to_i)
    render json: success_json
  end

end
