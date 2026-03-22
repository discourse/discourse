# frozen_string_literal: true

module DiscourseWorkflows
  class ExpressionResolver
    EXPRESSION_REGEX = /\{\{(.*?)\}\}/
    WHOLE_EXPRESSION_REGEX = /\A\{\{\s*([^{}]*?)\s*\}\}\z/
    NODE_REF_REGEX = /\A\$\(['"](.+?)['"]\)\.item\.json\.(.+)\z/
    NODE_CONTEXT_REGEX = /\A\$\(['"](.+?)['"]\)\.context\["(.+?)"\]\z/
    LOOKUP_FAILURES = [
      Discourse::InvalidParameters,
      SiteSettingExtension::InvalidSettingAccess,
    ].freeze

    def initialize(
      context,
      variable_store: VariableStore.new,
      site_setting_store: SiteSettingStore.new
    )
      @lookup =
        LookupChain.new(
          context: context,
          variable_store: variable_store,
          site_setting_store: site_setting_store,
        )
    end

    def resolve(value)
      return value unless resolvable_string?(value)

      template = value[1..].strip
      expression = template.match(WHOLE_EXPRESSION_REGEX)&.captures&.first

      return resolve_expression(expression) if expression

      render_template(template)
    end

    def resolve_hash(hash)
      resolve_tree(hash)
    end

    private

    def resolve_tree(value)
      case value
      when Hash
        value.transform_values { |nested_value| resolve_tree(nested_value) }
      when Array
        value.map { |item| resolve_tree(item) }
      else
        resolve(value)
      end
    end

    def resolvable_string?(value)
      value.is_a?(String) && value.start_with?("=")
    end

    def resolve_expression(expression)
      safely_lookup(expression, fallback: nil)
    end

    def render_template(template)
      template.gsub(EXPRESSION_REGEX) do
        expression = Regexp.last_match(1).strip
        safely_lookup(expression, fallback: "") { |value| format_value(value) }
      end
    end

    def safely_lookup(expression, fallback:)
      value = @lookup.resolve(expression)
      block_given? ? yield(value) : value
    rescue *LOOKUP_FAILURES
      fallback
    end

    def format_value(value)
      value.is_a?(Array) ? value.join(", ") : value.to_s
    end

    class LookupChain
      def initialize(context:, variable_store:, site_setting_store:)
        @resolvers = [
          NodeContextLookup.new(context),
          NodeOutputLookup.new(context),
          SiteSettingLookup.new(site_setting_store),
          JsonLookup.new(context),
          VariableLookup.new(variable_store),
          ContextLookup.new(context),
        ]
      end

      def resolve(expression)
        normalized_expression = expression.strip
        resolver_for(normalized_expression).resolve(normalized_expression)
      end

      private

      def resolver_for(expression)
        @resolvers.find { |resolver| resolver.match?(expression) }
      end
    end

    class LookupBase
      private

      def resolve_dot_path(object, path)
        keys = path.split(".")
        keys.reduce(object) { |value, key| value.is_a?(Hash) ? value[key] : nil }
      end
    end

    class NodeContextLookup < LookupBase
      def initialize(context)
        @context = context
      end

      def match?(expression)
        expression.match?(NODE_CONTEXT_REGEX)
      end

      def resolve(expression)
        match = expression.match(NODE_CONTEXT_REGEX)
        node_context = @context.dig("_node_contexts", match[1]) || {}
        node_context[match[2]]
      end
    end

    class NodeOutputLookup < LookupBase
      def initialize(context)
        @context = context
      end

      def match?(expression)
        expression.match?(NODE_REF_REGEX)
      end

      def resolve(expression)
        match = expression.match(NODE_REF_REGEX)
        node_items = @context[match[1]]
        item_json = extract_first_item_json(node_items)

        resolve_dot_path(item_json, match[2])
      end

      private

      def extract_first_item_json(node_data)
        if node_data.is_a?(Array) && node_data.first.is_a?(Hash) && node_data.first.key?("json")
          node_data.first["json"] || {}
        elsif node_data.is_a?(Hash)
          node_data
        else
          {}
        end
      end
    end

    class SiteSettingLookup
      PREFIX = "$site_settings."

      def initialize(site_setting_store)
        @site_setting_store = site_setting_store
      end

      def match?(expression)
        expression.start_with?(PREFIX)
      end

      def resolve(expression)
        setting_name = expression.delete_prefix(PREFIX)
        @site_setting_store.fetch(setting_name)
      end
    end

    class JsonLookup < LookupBase
      PREFIX = "$json."

      def initialize(context)
        @context = context
      end

      def match?(expression)
        expression.start_with?(PREFIX)
      end

      def resolve(expression)
        key = expression.delete_prefix(PREFIX)
        resolve_dot_path(@context["$json"] || {}, key)
      end
    end

    class VariableLookup
      PREFIX = "$vars."

      def initialize(variable_store)
        @variable_store = variable_store
      end

      def match?(expression)
        expression.start_with?(PREFIX)
      end

      def resolve(expression)
        key = expression.delete_prefix(PREFIX)
        @variable_store.fetch(key)
      end
    end

    class ContextLookup < LookupBase
      def initialize(context)
        @context = context
      end

      def match?(_expression)
        true
      end

      def resolve(expression)
        resolve_dot_path(@context, expression)
      end
    end

    class VariableStore
      def initialize
        @values_by_key = {}
      end

      def fetch(key)
        return @values_by_key[key] if @values_by_key.key?(key)

        @values_by_key[key] = DiscourseWorkflows::Variable.find_by(key: key)&.value
      end
    end

    class SiteSettingStore
      def initialize
        @values_by_name = {}
      end

      def fetch(name)
        return @values_by_name[name] if @values_by_name.key?(name)

        @values_by_name[name] = SiteSetting.get(name)
      end
    end
  end
end
