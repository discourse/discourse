# frozen_string_literal: true

module Api
  class GroupsController < JsonApiKit::BaseController
    before_action :ensure_admin

    resource :groups
  end
end
