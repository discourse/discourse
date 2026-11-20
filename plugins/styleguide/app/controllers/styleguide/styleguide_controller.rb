# frozen_string_literal: true

module Styleguide
  class StyleguideController < ApplicationController
    requires_plugin PLUGIN_NAME
    skip_before_action :check_xhr

    def index
      return raise Discourse::NotFound if !guardian.can_see_styleguide?

      render "default/empty"
    end

    # The design variables core defines, and which of them generated theme
    # styles may change, read from core's compiled CSS.
    def design_variables
      raise Discourse::NotFound if !guardian.can_see_styleguide?

      registry = AppearanceStyles::VariableRegistry.instance
      render json: {
               design_variables:
                 registry.all.map do |variable|
                   {
                     name: variable.name,
                     type: variable.type,
                     scope: variable.scope,
                     default: variable.default,
                     selectors: variable.selectors,
                     editable: variable.allowed,
                     reason: variable.reason,
                     min_px: variable.min_px,
                     max_px: variable.max_px,
                     keywords: variable.keywords,
                   }
                 end,
               palette_variables: registry.palette_variables,
             }
    end
  end
end
