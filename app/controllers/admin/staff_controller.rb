# frozen_string_literal: true

class Admin::StaffController < ApplicationController
  include WithServiceHelper

  requires_login
  before_action :ensure_staff
end
