# frozen_string_literal: true

class EmailStyleSerializer < ApplicationSerializer
  root 'email_style'

  attributes :id, :html, :css, :default_html, :default_css
end
