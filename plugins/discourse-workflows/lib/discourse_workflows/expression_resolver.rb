# frozen_string_literal: true

module DiscourseWorkflows
  class ExpressionResolver
    EXPRESSION_REGEX = /\{\{(.*?)\}\}/
    WHOLE_EXPRESSION_REGEX = /\A\{\{\s*([^{}]*?)\s*\}\}\z/

    def initialize(
      context,
      variable_store: VariableStore.new,
      site_setting_store: SiteSettingStore.new,
      user: nil
    )
      @context = context
      @variable_store = variable_store
      @site_setting_store = site_setting_store
      @user = user
    end

    def resolve(value)
      return value unless resolvable_string?(value)

      template = value[1..].strip
      expression = template.match(WHOLE_EXPRESSION_REGEX)&.captures&.first

      return js_evaluator.evaluate(expression) if expression

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

    def render_template(template)
      template.gsub(EXPRESSION_REGEX) do
        expression = Regexp.last_match(1).strip
        format_value(js_evaluator.evaluate(expression))
      end
    end

    def js_evaluator
      @js_evaluator ||=
        JsEvaluator.new(
          @context,
          variable_store: @variable_store,
          site_setting_store: @site_setting_store,
          user: @user,
        )
    end

    def format_value(value)
      return "" if value.nil?
      value.is_a?(Array) ? value.join(", ") : value.to_s
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

        @values_by_name[name] = if SiteSetting.secret_settings.include?(name.to_s.to_sym)
          "[FILTERED]"
        else
          SiteSetting.get(name)
        end
      end
    end

    class JsEvaluator
      TIMEOUT = 500
      MAX_MEMORY = 10_000_000
      MARSHAL_STACK_DEPTH = 20

      def initialize(context, variable_store:, site_setting_store:, user: nil)
        @context = context
        @variable_store = variable_store
        @site_setting_store = site_setting_store
        @user = user
        @js_context = nil
      end

      def evaluate(expression)
        ensure_context!
        @js_context.eval(expression)
      rescue MiniRacer::Error
        nil
      end

      private

      def ensure_context!
        return if @js_context

        @js_context =
          MiniRacer::Context.new(
            timeout: TIMEOUT,
            max_memory: MAX_MEMORY,
            marshal_stack_depth: MARSHAL_STACK_DEPTH,
          )
        inject_data!
      end

      def inject_data!
        data = build_data
        @js_context.eval("var __data = #{data.to_json};")
        @js_context.attach(
          "__getSiteSetting",
          ->(name) do
            @site_setting_store.fetch(name)&.to_s
          rescue StandardError
            nil
          end,
        )
        @js_context.eval(setup_js)
      end

      def build_data
        node_outputs = {}
        node_contexts = @context["_node_contexts"] || {}

        @context.each do |key, value|
          next if key.start_with?("_") || key == "$json"
          node_outputs[key] = extract_item_json(value)
        end

        {
          "$json" => @context["$json"] || {},
          "trigger" => @context["trigger"] || {},
          "$vars" => DiscourseWorkflows::Variable.pluck(:key, :value).to_h,
          "$current_user" => build_current_user,
          "$execution" => @context["_execution"] || {},
          "_nodes" => node_outputs,
          "_node_contexts" => node_contexts,
        }
      end

      def setup_js
        <<~JS
          var $json = __data["$json"];
          var trigger = __data["trigger"];
          var $vars = __data["$vars"];
          var $current_user = __data["$current_user"];
          var $execution = __data["$execution"];
          var $site_settings = new Proxy({}, {
            get: function(target, prop) {
              if (prop in target) return target[prop];
              target[prop] = __getSiteSetting(prop);
              return target[prop];
            }
          });
          function $(name) {
            return {
              item: { json: __data._nodes[name] || {} },
              context: __data._node_contexts[name] || {}
            };
          }
        JS
      end

      def build_current_user
        return {} unless @user
        { "id" => @user.id, "username" => @user.username }
      end

      def extract_item_json(node_data)
        if node_data.is_a?(Array) && node_data.first.is_a?(Hash) && node_data.first.key?("json")
          node_data.first["json"] || {}
        elsif node_data.is_a?(Hash)
          node_data
        else
          {}
        end
      end
    end
  end
end
