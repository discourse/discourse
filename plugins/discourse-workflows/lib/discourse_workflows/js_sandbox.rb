# frozen_string_literal: true

module DiscourseWorkflows
  class JsSandbox
    TIMEOUT = 500
    MAX_MEMORY = 10_000_000
    MARSHAL_STACK_DEPTH = 20

    attr_reader :js_context, :workflow_context

    def initialize(workflow_context, user: nil, vars: nil)
      @workflow_context = workflow_context
      @user = user
      @vars = vars || DiscourseWorkflows::Variable.pluck(:key, :value).to_h
      @site_setting_store = SiteSettingStore.new
      @js_context = create_js_context
      setup_core_environment!
    end

    def eval(code)
      @js_context.eval(code)
    end

    def attach(name, callable)
      @js_context.attach(name, callable)
    end

    def dispose
      @js_context&.dispose
      @js_context = nil
    end

    def self.extract_item_json(node_data)
      if node_data.is_a?(Array) && node_data.first.is_a?(Hash) && node_data.first.key?("json")
        node_data.first["json"] || {}
      elsif node_data.is_a?(Hash)
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
        @values_by_name[name] =
          if SiteSetting.secret_settings.include?(sym) || SiteSetting.hidden_settings.include?(sym)
            "[FILTERED]"
          else
            SiteSetting.get(name)
          end
      end
    end

    private

    def create_js_context
      MiniRacer::Context.new(
        timeout: TIMEOUT,
        max_memory: MAX_MEMORY,
        marshal_stack_depth: MARSHAL_STACK_DEPTH,
      )
    end

    def setup_core_environment!
      @js_context.attach("__getSiteSetting", method(:fetch_site_setting))
      @js_context.attach("__getNodeOutput", method(:fetch_node_output))

      @js_context.eval(<<~JS)
        var $vars = #{@vars.to_json};
        var $current_user = #{build_current_user.to_json};
        var $site_settings = new Proxy({}, {
          get: function(target, prop) {
            if (prop in target) return target[prop];
            target[prop] = __getSiteSetting(prop);
            return target[prop];
          }
        });
        function $(name) {
          var data = JSON.parse(__getNodeOutput(name));
          return { item: { json: data } };
        }
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
      { "id" => @user.id, "username" => @user.username }
    end
  end
end
