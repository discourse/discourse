# frozen_string_literal: true

module DiscourseAi
  module Agents
    class WorkflowTool
      BUILT_INS = [
        Tools::Time,
        Tools::ListCategories,
        Tools::ListUsers,
        Tools::RandomPicker,
        Tools::ListTags,
        Tools::Search,
        Tools::Read,
        Tools::ReadPost,
      ].freeze

      # The forum readers need a tokenizer and token budget, not completion.
      TOKEN_BUDGET =
        Struct
          .new(:max_prompt_tokens, :tokenizer)
          .new(16_000, DiscourseAi::Tokenizer::OpenAiCl100kTokenizer)
          .freeze

      def self.built_ins
        BUILT_INS & Agent.all_available_tools
      end

      def self.custom_tools
        ::AiTool.where(enabled: true).includes(:secret_bindings)
      end

      def self.custom_eligible?(tool)
        tool.secret_contracts.blank? && tool.secret_bindings.empty?
      end

      def self.options
        built_ins.map do |tool|
          { id: "builtin:#{tool.name}", name: AiToolSerializer.new(tool).name, custom: false }
        end +
          custom_tools.filter_map do |tool|
            next if !custom_eligible?(tool)
            {
              id: "custom:#{tool.id}",
              name: I18n.t("discourse_ai.tools.custom_name", name: tool.name),
              custom: true,
            }
          end
      end

      def self.find(reference)
        return if !reference.is_a?(String)

        source, id = reference.split(":", 2)
        case source
        when "builtin"
          tool = built_ins.find { |candidate| candidate.name == id }
        when "custom"
          return if !id&.match?(/\A[1-9][0-9]*\z/)
          tool = custom_tools.find_by(id: id)
          return if !tool || !custom_eligible?(tool)
        end
        new(tool) if tool
      end

      def initialize(tool)
        @tool = tool
      end

      def custom?
        @tool.is_a?(::AiTool)
      end

      def arguments
        @arguments ||=
          Array(@tool.signature[:parameters]).map do |parameter|
            {
              name: parameter[:name].to_s,
              type: parameter[:type],
              description: parameter[:description],
              required: parameter[:required] == true,
              enum: parameter[:enum],
              item_type: parameter[:item_type],
            }.compact
          end
      end

      def argument_schema
        {
          "type" => "object",
          "properties" =>
            arguments.to_h do |argument|
              schema = { "type" => argument.fetch(:type) }
              schema["enum"] = argument[:enum] if argument[:enum]
              schema["items"] = { "type" => argument[:item_type] } if argument[:item_type]
              [argument.fetch(:name), schema]
            end,
          "required" => arguments.select { |argument| argument[:required] }.pluck(:name),
          "additionalProperties" => false,
        }
      end

      def invoke(arguments, actor:, llm: nil)
        context =
          BotContext.new(user: actor, guardian: actor.guardian, feature_name: "workflow_ai_tool")

        if custom?
          @tool.runner(arguments, llm: llm, bot_user: actor, context: context).invoke
        else
          @tool
            .new(arguments.symbolize_keys, llm: TOKEN_BUDGET, bot_user: actor, context: context)
            .invoke {}
        end
      end
    end
  end
end
