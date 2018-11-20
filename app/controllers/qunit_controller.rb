class QunitController < ApplicationController
  skip_before_action :check_xhr, :preload_json
  layout false

  # only used in test / dev
  def index
    raise Discourse::InvalidAccess.new if Rails.env.production?
  end
end
