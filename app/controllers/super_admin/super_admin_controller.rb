# frozen_string_literal: true

class SuperAdmin::SuperAdminController < ApplicationController
  requires_login
  before_action :ensure_admin

  def index
    render body: nil
  end
end
