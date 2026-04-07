# frozen_string_literal: true

module DiscourseWorkflows
  class WaitForForm < WaitForResume
    attr_reader :form_fields, :form_title, :form_description

    def initialize(form_fields:, form_title: nil, form_description: nil)
      @form_fields = form_fields
      @form_title = form_title
      @form_description = form_description
      super(type: :form, message: "Workflow paused waiting for form submission")
    end
  end
end
