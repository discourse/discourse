# frozen_string_literal: true

module Chat
  class ApiController < ::Chat::BaseController
    include Chat::WithServiceHelper
  end
end
