# frozen_string_literal: true

require_relative "template_support"

module Onebox
  class View < Mustache
    include TemplateSupport

    attr_reader :record

    def initialize(name, record)
      @record = record
      self.template_name = name
      self.template_path = load_paths.last
    end

    def to_html
      render(record)
    end
  end
end
