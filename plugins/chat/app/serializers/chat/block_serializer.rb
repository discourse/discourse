# frozen_string_literal: true

module Chat
  class BlockSerializer < ApplicationSerializer
    attributes :type, :elements
    attributes :title,
               :cooked_title,
               :cooked_question,
               :cooked_status,
               :parameters,
               :changes,
               :cooked_error

    attributes :show_description, :description_label

    def description_label
      object["description_label"]
    end

    def show_description
      object.fetch("show_description", true)
    end

    def include_title?
      type == "confirmation"
    end

    alias include_cooked_question? include_title?
    alias include_parameters? include_title?
    alias include_show_description? include_title?
    alias include_description_label? include_title?
    alias include_cooked_title? include_title?
    alias include_changes? include_title?
    alias include_cooked_error? include_title?

    def changes
      object["changes"] || []
    end

    def cooked_title
      Chat::Message.cook(object["title"], user_id: @options[:user_id])
    end

    def cooked_error
      Chat::Message.cook(object["error"].to_s, user_id: @options[:user_id])
    end

    def include_cooked_status?
      type == "confirmation" && object["status"].present?
    end

    def title
      object["title"]
    end

    def cooked_question
      Chat::Message.cook(object["question"], user_id: @options[:user_id])
    end

    def parameters
      object["parameters"]
    end

    def cooked_status
      Chat::Message.cook(object["status"], user_id: @options[:user_id])
    end

    def type
      object["type"]
    end

    def elements
      object["elements"].map do |element|
        serializer = self.class.element_serializer_for(element["type"])
        serializer.new(element, root: false).as_json
      end
    end

    def self.element_serializer_for(type)
      case type
      when "button"
        Chat::Blocks::Elements::ButtonSerializer
      when "category"
        Chat::Blocks::Elements::CategorySerializer
      else
        raise "no serializer for #{type}"
      end
    end
  end
end
