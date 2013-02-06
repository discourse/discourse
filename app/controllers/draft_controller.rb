class DraftController < ApplicationController
  before_filter :ensure_logged_in
  skip_before_filter :check_xhr

  def show
    seq = params[:sequence] || DraftSequence.current(current_user, params[:draft_key])
    render :json => {draft: Draft.get(current_user, params[:draft_key], seq), draft_sequence: seq}
  end

  def update
    Draft.set(current_user, params[:draft_key], params[:sequence].to_i, params[:data])
    render :text => 'ok'
  end

  def destroy
    Draft.clear(current_user, params[:draft_key], params[:sequence].to_i)
    render :text => 'ok'
  end

end
