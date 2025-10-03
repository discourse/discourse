# frozen_string_literal: true

module DiscourseSubscriptions
  class PricingtableController < ::ApplicationController
    requires_plugin PLUGIN_NAME

    def index
      head 200
    end
  end
end
