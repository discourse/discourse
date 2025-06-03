# frozen_string_literal: true

class ReviewableNotesController < ApplicationController
  before_action :find_reviewable

  def create
    note = @reviewable.reviewable_notes.build(note_params)
    note.user = current_user

    if note.save
      # Reload to ensure associations are loaded
      note.reload
      render json: ReviewableNoteSerializer.new(note, scope: guardian, root: false)
    else
      render json: { errors: note.errors.full_messages }, status: 422
    end
  end

  def destroy
    note = @reviewable.reviewable_notes.find(params[:id])

    # Only allow the author or admin to delete notes
    raise Discourse::InvalidAccess unless note.user == current_user || current_user.admin?

    note.destroy!
    render json: success_json
  end

  private

  def find_reviewable
    @reviewable = Reviewable.find(params[:reviewable_id])
  end

  def note_params
    params.require(:reviewable_note).permit(:content)
  end
end
