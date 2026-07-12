# frozen_string_literal: true

class SuperAdmin::StaffController < ApplicationController
  requires_login
  before_action :ensure_staff
end
