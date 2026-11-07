# frozen_string_literal: true

module ::Lovelace
  class MemberChecklistsController < ::ApplicationController
    requires_plugin PLUGIN_NAME
    requires_login

    def show
      render json: MemberChecklist.for_user(current_user)
    end

    def update
      render json: MemberChecklist.update!(current_user, params)
    end
  end
end
