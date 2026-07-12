# frozen_string_literal: true

class SuperAdmin::UnknownReviewablesController < SuperAdmin::SuperAdminController
  def destroy
    Reviewable.destroy_unknown_types!
    render json: success_json
  end
end
