# frozen_string_literal: true

module DiscourseWorkflows
  class Template::Show
    include Service::Base

    params do
      attribute :template_id, :string

      validates :template_id, presence: true, format: { with: /\A[a-z0-9_-]+\z/ }
    end

    model :template

    private

    def fetch_template(params:)
      path = File.join(DiscourseWorkflows::TEMPLATES_PATH, "#{params.template_id}.json")
      return unless File.exist?(path)
      JSON.parse(File.read(path))
    rescue JSON::ParserError
      nil
    end
  end
end
