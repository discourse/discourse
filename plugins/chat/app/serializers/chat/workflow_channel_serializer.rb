# frozen_string_literal: true

module Chat
  class WorkflowChannelSerializer < ApplicationSerializer
    PROPERTIES = {
      "id" => {
        "type" => "integer",
      },
      "title" => {
        "type" => "string",
      },
      "slug" => {
        "type" => "string",
      },
      "chatable_type" => {
        "type" => "string",
      },
      "chatable_id" => {
        "type" => "integer",
      },
    }.freeze

    attributes(*PROPERTIES.keys.map(&:to_sym))

    def title
      object.title(scope.user)
    end
  end
end
