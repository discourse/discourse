# frozen_string_literal: true

class DiscardedDraftsController < ApplicationController
  requires_login

  def index
    drafts =
      Draft
        .discarded
        .where(user_id: current_user.id)
        .order(deleted_at: :desc, id: :desc)
        .offset(params[:offset].to_i)
        .limit(
          fetch_limit_from_params(
            default: DraftsController::INDEX_LIMIT,
            max: DraftsController::INDEX_LIMIT,
          ),
        )
        .to_a
    Draft.preload_data(drafts, current_user)

    response = { discarded_drafts: serialize_data(drafts, DraftSerializer) }

    if guardian.can_lazy_load_categories?
      category_ids = drafts.map { |draft| draft.topic&.category_id }.compact.uniq
      categories = Category.secured(guardian).with_parents(category_ids)
      response[:categories] = serialize_data(categories, CategoryBadgeSerializer)
    end

    render json: response
  end

  def restore
    draft = find_discarded_draft

    if Draft.live.where(user_id: current_user.id).count >= SiteSetting.max_drafts_per_user
      return(
        render_json_error I18n.t("draft.too_many_drafts.title"),
                          status: 403,
                          extras: {
                            description:
                              I18n.t(
                                "draft.too_many_drafts.description",
                                base_url: Discourse.base_url,
                              ),
                          }
      )
    end

    begin
      draft.restore!
    rescue Draft::RestoreConflict
      return render_json_error I18n.t("draft.restore_conflict"), status: 409
    end

    render json: { draft: draft.data, draft_sequence: draft.sequence }
  end

  def destroy
    draft = find_discarded_draft
    draft.with_lock do
      raise Discourse::NotFound if draft.deleted_at.nil?
      draft.destroy!
    end
    head :no_content
  end

  private

  def find_discarded_draft
    Draft.discarded.find_by(id: params[:id], user_id: current_user.id) || raise(Discourse::NotFound)
  end
end
