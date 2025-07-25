# frozen_string_literal: true

module DiscourseUserNotes
  class UserNotesController < ::ApplicationController
    requires_plugin DiscourseUserNotes::PLUGIN_NAME
    before_action :ensure_logged_in
    before_action :ensure_staff

    def index
      user = User.where(id: params[:user_id]).first
      raise Discourse::NotFound if user.blank?

      notes = ::DiscourseUserNotes.notes_for(params[:user_id])
      render json: { extras: { username: user.username }, user_notes: create_json(notes.reverse) }
    end

    def create
      user = User.where(id: params[:user_note][:user_id]).first
      raise Discourse::NotFound if user.blank?
      extras = {}
      if post_id = params[:user_note][:post_id]
        extras[:post_id] = post_id
      end

      user_note =
        ::DiscourseUserNotes.add_note(user, params[:user_note][:raw], current_user.id, extras)

      render json: create_json(user_note)
    end

    def destroy
      user = User.where(id: params[:user_id]).first
      raise Discourse::NotFound if user.blank?

      raise Discourse::InvalidAccess.new unless guardian.can_delete_user_notes?

      ::DiscourseUserNotes.remove_note(user, params[:id])
      render json: success_json
    end

    protected

    def create_json(obj)
      # Avoid n+1
      if obj.is_a?(Array)
        users_by_id = {}
        posts_by_id = {}
        User.where(id: obj.map { |o| o[:created_by] }).each { |u| users_by_id[u.id] = u }
        Post.with_deleted.where(id: obj.map { |o| o[:post_id] }).each { |p| posts_by_id[p.id] = p }
        obj.each do |o|
          o[:created_by] = users_by_id[o[:created_by].to_i]
          o[:post] = posts_by_id[o[:post_id].to_i]
        end
      else
        obj[:created_by] = User.where(id: obj[:created_by]).first
        obj[:post] = Post.with_deleted.where(id: obj[:post_id]).first
      end

      serialize_data(obj, ::UserNoteSerializer)
    end
  end
end
