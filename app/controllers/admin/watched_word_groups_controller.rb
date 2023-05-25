# frozen_string_literal: true

class Admin::WatchedWordGroupsController < Admin::StaffController
  before_action :find_watched_word_group, only: %i[update destroy]

  def create
    group = WatchedWordGroup.create_membership(watched_word_group_params)

    # TODO: use valid?
    if group.errors.empty?
      StaffActionLogger.new(current_user).log_create_watched_word_group(group)

      render json: { id: group.id, words: group.watched_words }, root: false
    else
      render_json_error(group)
    end
  end

  def update
    group = @watched_word_group.update_membership(watched_word_group_params.except(:id))
    current_words = @watched_word_group.watched_words

    # TODO: use valid?
    if group.errors.empty?
      StaffActionLogger.new(current_user).log_update_watched_word_group(
        group.reload,
        old_members: current_words,
      )

      render json: { id: group.id, words: group.watched_words }, root: false
    else
      render_json_error(group)
    end
  end

  def destroy
    current_words = @watched_word_group.watched_words
    @watched_word_group.destroy!

    StaffActionLogger.new(current_user).log_delete_watched_word_group(
      @watched_word_group,
      deleted_members: current_words,
    )

    render json: success_json
  end

  private

  def find_watched_word_group
    @watched_word_group = WatchedWordGroup.includes(:watched_words).find_by(id: params[:id])

    raise Discourse::NotFound unless @watched_word_group
  end

  def watched_word_group_params
    params[:action_key] = params[:action_key].to_sym
    params.permit(:id, :replacement, :action_key, :case_sensitive, words: [])
  end
end
