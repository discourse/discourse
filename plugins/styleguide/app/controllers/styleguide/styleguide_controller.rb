# frozen_string_literal: true

module Styleguide
  class StyleguideController < ApplicationController
    requires_plugin PLUGIN_NAME
    skip_before_action :check_xhr

    def index
      return raise Discourse::NotFound if !guardian.can_see_styleguide?

      render "default/empty"
    end
  end
end
