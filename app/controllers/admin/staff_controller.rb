# frozen_string_literal: true

class Admin::StaffController < ApplicationController
  requires_login
  before_action :ensure_staff
end
