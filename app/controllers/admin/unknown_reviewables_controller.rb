# frozen_string_literal: true

class Admin::UnknownReviewablesController < Admin::AdminController
  def destroy
    Reviewable
      .pending
      .where.not(type: Reviewable.types.map { |reviewable| reviewable.new.type })
      .delete_all
    render json: success_json
  end
end
