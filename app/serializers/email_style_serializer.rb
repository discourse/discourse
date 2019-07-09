# frozen_string_literal: true

class EmailStyleSerializer < ApplicationSerializer
  attributes :html, :css, :default_html, :default_css
end
