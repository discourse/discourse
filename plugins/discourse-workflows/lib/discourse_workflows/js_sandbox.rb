# frozen_string_literal: true

module DiscourseWorkflows
  class JsSandbox
    EVAL_TIMEOUT_MS = 500
    MAX_INJECTED_JSON_BYTES = 1.megabyte
    MAX_MEMORY_BYTES = 10.megabytes
    MARSHAL_STACK_DEPTH = 20

    attr_reader :js_context, :workflow_context, :log

    class BudgetExceededError < StandardError
    end

    class PayloadTooLargeError < StandardError
    end

    def initialize(workflow_context, user: nil, vars: nil, capture_logs: false, budget_tracker: nil)
      @workflow_context = workflow_context
      @user = user
      @vars = vars || DiscourseWorkflows::Variable.pluck(:key, :value).to_h
      @budget_tracker = budget_tracker
      @site_setting_store = SiteSettingStore.new
      @js_context = create_js_context
      setup_core_environment!
      setup_console_capture! if capture_logs
    end

    def eval(code)
      started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      @js_context.eval(code)
    ensure
      finish_eval!(started_at)
    end

    def rebind_code_item(item, item_index: 0)
      item_js = serialize_json_payload(item, label: "$input.item")
      self.eval("$input.item = #{item_js}; __itemIndex = #{item_index};")
    end

    def rebind_expression_item(item, item_index: 0)
      item_js = serialize_json_payload(item, label: "$input.item")
      self.eval(
        "$input.item = #{item_js}; " \
          "__data[\"__inputItem\"] = $input.item; " \
          "__data[\"$json\"] = $input.item.json; " \
          "__data[\"$itemIndex\"] = #{item_index};",
      )
    end

    def declare_json(name, value)
      value_js = serialize_json_payload(value, label: name)
      self.eval("var #{name} = #{value_js};")
    end

    def attach(name, callable)
      @js_context.attach(name, callable)
    end

    def self.serialize_json_payload(value, label:)
      payload = value.to_json

      return payload if payload.bytesize <= MAX_INJECTED_JSON_BYTES

      raise PayloadTooLargeError,
            "Sandbox payload '#{label}' exceeds #{MAX_INJECTED_JSON_BYTES} bytes"
    end

    def dispose
      @js_context&.dispose
      @js_context = nil
    end

    def self.extract_item_json(node_data)
      case node_data
      when Array
        node_data.dig(0, "json") || {}
      when Hash
        node_data
      else
        {}
      end
    end

    class SiteSettingStore
      def initialize
        @values_by_name = {}
      end

      def fetch(name)
        return @values_by_name[name] if @values_by_name.key?(name)

        sym = name.to_s.to_sym
        @values_by_name[name] = if SiteSetting.secret_settings.include?(sym) ||
             SiteSetting.hidden_settings.include?(sym)
          "[FILTERED]"
        else
          SiteSetting.get(name)
        end
      end
    end

    private

    def create_js_context
      MiniRacer::Context.new(
        timeout: EVAL_TIMEOUT_MS,
        max_memory: MAX_MEMORY_BYTES,
        marshal_stack_depth: MARSHAL_STACK_DEPTH,
      )
    end

    def setup_core_environment!
      @js_context.attach("__getSiteSetting", method(:fetch_site_setting))
      @js_context.attach("__getNodeOutput", method(:fetch_node_output))

      execution = @workflow_context.fetch("__execution") { {} }
      declare_json("__vars", @vars)
      declare_json("__executionData", execution)
      declare_json("__currentUser", build_current_user)

      eval(<<~JS)
        Object.defineProperty(this, '$vars', {
          value: Object.freeze(__vars)
        });
        Object.defineProperty(this, '$execution', {
          value: Object.freeze(__executionData)
        });
        Object.defineProperty(this, '$current_user', {
          value: Object.freeze(__currentUser)
        });
        Object.defineProperty(this, '$site_settings', {
          value: new Proxy({}, {
            get: function(target, prop) {
              if (prop in target) return target[prop];
              target[prop] = __getSiteSetting(prop);
              return target[prop];
            },
            set: function() { return false; }
          })
        });
        Object.defineProperty(this, '$', {
          value: function(name) {
            var data = JSON.parse(__getNodeOutput(name));
            return { item: { json: data } };
          },
          configurable: true,
          writable: true
        });
      JS
    end

    def fetch_site_setting(name)
      @site_setting_store.fetch(name)&.to_s
    rescue StandardError
      nil
    end

    def fetch_node_output(name)
      return {}.to_json if name.to_s.start_with?("_")
      self.class.extract_item_json(@workflow_context[name]).to_json
    end

    def build_current_user
      return {} unless @user
      ExpressionContextSchema
        .environment_symbols
        .dig("$current_user", :fields)
        .to_h { |field_name, _| [field_name, @user.public_send(field_name)] }
    end

    def setup_console_capture!
      @log = Executor::StepLog.new
      capture = proc { |level, *args| @log.public_send(level, args.map(&:to_s).join(" ")) }
      @js_context.attach("__captureLog", proc { |*args| capture.call(:info, *args) })
      @js_context.attach("__captureWarn", proc { |*args| capture.call(:warn, *args) })
      @js_context.attach("__captureError", proc { |*args| capture.call(:error, *args) })

      eval(<<~JS)
        Object.defineProperty(this, 'console', {
          value: Object.freeze({
            log: function() { __captureLog(...arguments); },
            info: function() { __captureLog(...arguments); },
            warn: function() { __captureWarn(...arguments); },
            error: function() { __captureError(...arguments); }
          })
        });
      JS
    end

    def finish_eval!(started_at)
      return unless started_at

      elapsed_ms = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1000.0
      @budget_tracker&.charge!(elapsed_ms)
    end

    def serialize_json_payload(value, label:)
      self.class.serialize_json_payload(value, label:)
    end
  end
end
