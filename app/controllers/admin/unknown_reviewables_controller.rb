# frozen_string_literal: true

class Admin::UnknownReviewablesController < Admin::AdminController
  def destroy
    Reviewable.destroy_unknown_types!
    render json: success_json
  end
end
