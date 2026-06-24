# frozen_string_literal: true

module DiscourseWorkflows
  class Executor
    class NodeExecutionContext
      MISSING = ParameterResolver::MISSING
      RUN_CODE = CodeRunner::RUN_CODE
      RUN_ONCE_FOR_ALL_ITEMS = CodeRunner::RUN_ONCE_FOR_ALL_ITEMS
      RUN_ONCE_FOR_EACH_ITEM = CodeRunner::RUN_ONCE_FOR_EACH_ITEM
      JAVASCRIPT_UNDEFINED = CodeRunner::JAVASCRIPT_UNDEFINED
      JobResult = Data.define(:ok, :result, :error)
      WaitRequest = Data.define(:waiting_until)

      def self.serialize_post(
        post,
        guardian: Discourse.system_user.guardian,
        include_raw: true,
        include_cooked: false
      )
        MultiJson.load(
          DiscourseWorkflows::PostSerializer.new(
            post,
            scope: guardian,
            root: false,
            include_raw: include_raw,
            include_cooked: include_cooked,
          ).to_json,
        ).deep_symbolize_keys
      end

      def self.serialize_topic(
        topic,
        guardian: Discourse.system_user.guardian,
        custom_field_names: []
      )
        MultiJson.load(
          DiscourseWorkflows::TopicSerializer.new(
            topic,
            scope: guardian,
            root: false,
            custom_field_names: custom_field_names,
          ).to_json,
        ).deep_symbolize_keys
      end

      def self.serialize_user(user, guardian: Discourse.system_user.guardian)
        return if user.blank?

        MultiJson.load(
          DiscourseWorkflows::UserSerializer.new(user, scope: guardian, root: false).to_json,
        ).deep_symbolize_keys
      end

      class RuntimeState
        attr_reader :condition_step_details, :execution_hints, :log, :metadata, :wait_request

        def initialize
          @condition_step_details = []
          @execution_hints = []
          @log = StepLog.new
          @metadata = {}
          @wait_request = nil
        end

        def request_wait(waiting_until)
          @wait_request = WaitRequest.new(waiting_until)
        end

        def add_condition_details(details)
          @condition_step_details.concat(details)
        end

        def add_execution_hints(hints)
          @execution_hints.concat(hints.map(&:deep_stringify_keys))
        end

        def merge_metadata(metadata)
          @metadata.merge!(metadata.deep_stringify_keys)
        end

        def step_metadata
          metadata = @metadata.dup
          metadata["conditions"] = @condition_step_details if @condition_step_details.any?
          metadata["hints"] = @execution_hints if @execution_hints.any?
          metadata
        end
      end

      attr_reader :user, :vars, :execution_id, :node_id, :webhook_ctx

      def initialize(
        input_items:,
        input_groups: nil,
        parameters: nil,
        credentials: {},
        node_settings: {},
        webhook_id: nil,
        property_schema: {},
        credential_schema: [],
        node_context: {},
        user: nil,
        resolver: nil,
        vars: nil,
        workflow: nil,
        execution_id: nil,
        resume_token: nil,
        node_id: nil,
        node_name: nil,
        node_identifier: nil,
        execution_mode: :normal,
        flow_context: nil,
        resolver_context: nil,
        workflow_dependencies: nil,
        workflow_snapshot: nil,
        webhook_context: nil,
        runtime_state: RuntimeState.new,
        static_data_state: nil
      )
        @input_groups = normalize_input_groups(input_groups, input_items)
        @input_items = @input_groups[0] || []
        split =
          NodeData.split(
            parameters: parameters || {},
            credentials: credentials,
            webhook_id: webhook_id,
          )
        @parameters = split["parameters"]
        @credentials = split["credentials"]
        @node_settings = node_settings.deep_stringify_keys
        @property_schema = property_schema
        @credential_schema = NodeData.normalize_credential_definitions(credential_schema)
        @node_context = node_context
        @user = user
        @resolver = resolver
        @vars = vars
        @workflow = workflow
        @execution_id = execution_id
        @resume_token = resume_token
        @node_id = node_id
        @node_name = node_name.presence&.to_s
        @node_identifier = node_identifier.presence&.to_s
        @webhook_id = split[DiscourseWorkflows::WorkflowDocument.node_webhook_id_key]
        @execution_mode = execution_mode
        @flow_context = flow_context || {}
        @resolver_context = resolver_context || {}
        @runtime_state = runtime_state
        @workflow_dependencies = workflow_dependencies
        @workflow_snapshot = workflow_snapshot
        @webhook_ctx = webhook_context
        @static_data_state = static_data_state
      end

      # Static data access.
      #
      # `get_workflow_static_data(:global)` returns the workflow-wide hash.
      # `get_workflow_static_data(:node)` returns the per-node hash for the
      # *current* node, keyed by node name. Mutations are persisted at the
      # end of the execution by `Executor#commit_static_data!`.
      def get_workflow_static_data(scope = :node)
        raise "static data is not available in this context" if @static_data_state.nil?

        case scope.to_s
        when "node"
          raise "static data node scope requires a node name" if @node_name.blank?
          @static_data_state.fetch_node(@node_name)
        when "global"
          @static_data_state.fetch(:global)
        else
          raise ArgumentError, "Unknown static data scope: #{scope.inspect}. Use :node or :global"
        end
      end

      def get_context(scope = :node)
        case scope
        when :node
          @node_context
        when :flow
          @flow_context
        else
          raise ArgumentError, "Unknown context scope: #{scope}. Use :node or :flow"
        end
      end

      def input_items(input_key = nil)
        return @input_items if input_key.nil?

        @input_groups.fetch(input_index(input_key)) { [] }
      end

      def inputs
        max_index = @input_groups.keys.max || 0
        Array.new(max_index + 1) { |index| @input_groups[index] || [] }
      end

      def input_context
        InputContext.from_node_context(get_context(:node))
      end

      def get_mode
        @execution_mode.to_s
      end

      def get_node
        DiscourseWorkflows::NodeView.from_snapshot_node(
          current_snapshot_node,
          include_node_parameters: true,
          include_credentials: true,
          include_webhook_id: true,
        ) ||
          DiscourseWorkflows::NodeView.new(
            id: node_id,
            name: nil,
            type: @node_identifier,
            type_version: nil,
            webhook_id: @webhook_id,
            parameters: @parameters,
            credentials: @credentials,
          )
      end

      def get_workflow
        DiscourseWorkflows::WorkflowView.from_workflow(
          @workflow,
          name: @workflow_snapshot&.workflow_name,
        )
      end

      def get_input_data(input_index = 0, _connection_type = nil)
        input_items(input_index)
      end

      def continue_on_fail
        on_error = @node_settings["onError"]
        return %w[continueRegularOutput continueErrorOutput].include?(on_error) if on_error.present?

        ActiveModel::Type::Boolean.new.cast(@node_settings["continueOnFail"]) == true
      end

      def start_job(job_type, settings, item_index)
        raise ArgumentError, "Unsupported job type: #{job_type}" unless job_type == "javascript"

        JobResult.new(
          ok: true,
          result: code_runner.run(settings.deep_stringify_keys, item_index),
          error: nil,
        )
      rescue => e
        JobResult.new(ok: false, result: nil, error: e)
      end

      def get_node_parameter(path, item_index = 0, default: nil, options: {})
        parameter_resolver.resolve(path, item_index, default:, options:)
      end

      def helpers
        @helpers ||=
          ContextHelpers.new(
            node_identifier: @node_identifier,
            data_table_access_validator: ->(data_table_id) do
              ensure_data_table_access!(data_table_id)
            end,
          )
      end

      def get_credentials(slot, item_index = 0)
        fetch_credentials(slot, item_index)
      end

      def actor_from_parameter(path, item_index = 0, default: "system")
        username = get_node_parameter(path, item_index, default: default)

        if username.blank?
          raise DiscourseWorkflows::NodeError,
                I18n.t("discourse_workflows.errors.actor.blank", field: path.to_s)
        end

        actor_from(username: username, field: path.to_s, item_index: item_index)
      end

      def actor_from(username: nil, id: nil, field: nil, item_index: nil)
        actor =
          if username == DiscourseWorkflows::AnonymousActor::USERNAME
            DiscourseWorkflows::AnonymousActor.new
          else
            find_user(username: username.presence, id: id)
          end
        ensure_actor_allowed!(actor, field: field, item_index: item_index)
        actor
      end

      def find_user(username: nil, id: nil)
        if username.present? == id.present?
          raise ArgumentError, "Provide exactly one of username or id"
        end

        if username.present?
          user = User.find_by(username: username)
          raise DiscourseWorkflows::NodeError, "User '#{username}' not found" if user.nil?
        else
          user = User.find_by(id: id)
          raise DiscourseWorkflows::NodeError, "User with id #{id} not found" if user.nil?
        end

        user
      end

      def http_request(method:, url:, headers: {}, body: nil, options: {}, item_index: 0)
        HttpClient.new(self, item_index).request(method:, url:, headers:, body:, options:)
      end

      def create_post(user:, raw:, topic_id:, reply_to_post_number: nil, whisper: false)
        topic = ::Topic.find(topic_id)
        guardian = user.guardian
        guardian.ensure_can_see!(topic)
        raise Discourse::InvalidAccess if !guardian.can_create_post?(topic)

        if topic.closed? || topic.archived?
          raise DiscourseWorkflows::NodeError,
                I18n.t("discourse_workflows.errors.post.topic_closed_or_archived")
        end

        post_args = {
          topic_id: topic.id,
          raw: raw,
          reply_to_post_number: reply_to_post_number.presence,
          skip_workflows: true,
        }.compact

        if ActiveModel::Type::Boolean.new.cast(whisper)
          unless guardian.can_create_whisper?
            raise Discourse::InvalidAccess.new(
                    "invalid_whisper_access",
                    nil,
                    custom_message: "invalid_whisper_access",
                  )
          end

          post_args[:post_type] = ::Post.types[:whisper]
        end

        PostCreator.new(user, post_args).create!
      end

      def edit_post(user:, post_id:, raw:)
        post = ::Post.find(post_id)
        raise Discourse::InvalidAccess if !user.guardian.can_edit_post?(post)

        if !PostRevisor.new(post).revise!(user, { raw: raw }, skip_workflows: true)
          errors = post.errors.full_messages.presence
          raise DiscourseWorkflows::NodeError,
                errors&.join(", ") || I18n.t("discourse_workflows.errors.post.edit_failed")
        end

        post.reload
      end

      def serialize_post(
        post,
        guardian: Discourse.system_user.guardian,
        include_raw: true,
        include_cooked: false
      )
        self.class.serialize_post(post, guardian:, include_raw:, include_cooked:)
      end

      def serialize_topic(topic, guardian: Discourse.system_user.guardian, custom_field_names: [])
        self.class.serialize_topic(topic, guardian:, custom_field_names:)
      end

      def put_execution_to_wait(waiting_until = nil)
        @runtime_state.request_wait(waiting_until)
      end

      def resume_action_id(action)
        DiscourseWorkflows::InteractiveResume.action_id(
          execution_id: execution_id,
          resume_token: @resume_token,
          action: action,
        )
      end

      def set_metadata(metadata)
        @runtime_state.merge_metadata(metadata)
      end

      def add_execution_hints(*hints)
        @runtime_state.add_execution_hints(hints)
      end

      def evaluate_expression(expression, item_index = 0)
        with_item_index(item_index) { @resolver.resolve(expression) }
      end

      def log
        @runtime_state.log
      end

      def execution_hints
        @runtime_state.execution_hints
      end

      def metadata
        @runtime_state.metadata
      end

      def get_child_nodes(node_name, options = {})
        graph_nodes(
          @workflow_snapshot&.child_nodes(node_name, connection_type: "main", depth: -1),
          include_node_parameters: graph_option(options, :include_node_parameters, false),
        )
      end

      def get_parent_nodes(node_name, options = {})
        graph_nodes(
          @workflow_snapshot&.parent_nodes(
            node_name,
            connection_type: graph_option(options, :connection_type, "main"),
            depth: graph_option(options, :depth, -1),
          ),
          include_node_parameters: graph_option(options, :include_node_parameters, false),
        )
      end

      def paired_item_for(item, input: 0)
        input_index = input_index(input)
        paired_item = { "item" => item_index_for(item, input_index:) }
        paired_item["input"] = input_index if input_index != 0
        paired_item
      end

      private

      def fetch_credentials(slot, item_index)
        raise ArgumentError, "credential slot is required" if slot.blank?

        credential_id = credential_id_for(slot)
        ensure_credential_access!(slot, credential_id)
        credential = DiscourseWorkflows::Credential.find_by(id: credential_id)
        raise Discourse::InvalidAccess if credential.nil?
        unless credential_type_allowed?(slot, credential.credential_type)
          raise Discourse::InvalidAccess
        end

        with_item_index(item_index) { @resolver.resolve_hash(credential.data || {}) }
      end

      def ensure_actor_allowed!(actor, field:, item_index:)
        actor_policy.ensure_allowed!(
          actor,
          field: field,
          item_index: item_index,
          source: actor_source(field, item_index),
          purpose: @node_identifier,
        )
      end

      def actor_policy
        @actor_policy ||= ActorPolicy.new(self)
      end

      def actor_source(field, item_index)
        return :direct if field.blank?

        raw_value = get_node_parameter(field, item_index || 0, options: { raw_expressions: true })
        return :default if raw_value.nil?
        return :expression if raw_value.is_a?(String) && raw_value.start_with?("=")

        :static_config
      end

      def current_snapshot_node
        @workflow_snapshot&.find_node(node_id)
      end

      def graph_nodes(nodes, include_node_parameters:)
        Array
          .wrap(nodes)
          .filter_map do |node|
            DiscourseWorkflows::NodeView.from_snapshot_node(
              node,
              include_node_parameters: include_node_parameters,
            )
          end
      end

      def graph_option(options, key, default)
        options = {} unless options.respond_to?(:[])
        options[key] || options[key.to_s] || default
      end

      def with_item_index(item_index = 0)
        normalized_item_index = normalize_item_index(item_index)
        item = input_items.fetch(normalized_item_index) { { "json" => {} } }

        @resolver.with_item(item, item_index: normalized_item_index) { yield item }
      end

      def ensure_data_table_access!(data_table_id)
        if @workflow && @node_id
          return if workflow_references_dependency?("data_table_id", data_table_id)
        elsif @parameters["data_table_id"].to_s == data_table_id
          return
        end

        raise Discourse::InvalidAccess
      end

      def ensure_credential_access!(slot, credential_id)
        raise Discourse::InvalidAccess if credential_id.blank? || !declared_credential_slot?(slot)

        if @workflow && @node_id
          return if workflow_references_dependency?("credential_id", credential_id)
        elsif credential_id_for(slot) == credential_id
          return
        end

        raise Discourse::InvalidAccess
      end

      def workflow_references_dependency?(type, key)
        if @workflow_dependencies
          @workflow_dependencies[@node_id].include?("#{type}:#{key}")
        else
          DiscourseWorkflows::WorkflowDependency.exists?(
            workflow_id: @workflow.id,
            node_id: @node_id,
            dependency_type: type,
            dependency_key: key,
          )
        end
      end

      def item_index_for(item, input_index: 0)
        @item_indexes_by_input_object_id ||=
          @input_groups.each_with_object({}) do |(index, items), result|
            result[index] = items.each_with_index.to_h do |entry, item_index|
              [entry.object_id, item_index]
            end
          end
        @item_indexes_by_input_object_id.fetch(input_index) { {} }.fetch(item.object_id, 0)
      end

      def normalize_input_groups(input_groups, input_items)
        groups = input_groups || { 0 => input_items }
        has_indexed_inputs =
          groups.keys.any? { |key| key.to_s.match?(/\Ainput_\d+\z/) || key.is_a?(Integer) }
        groups.each_with_object({}) do |(key, items), result|
          next if has_indexed_inputs && key.to_s == "main"

          result[input_index(key)] = items || []
        end
      end

      def input_index(input_key)
        return input_key if input_key.is_a?(Integer)

        value = input_key.to_s
        return 0 if value == "main"

        match = value.match(/\Ainput_(\d+)\z/)
        return match[1].to_i - 1 if match

        value.to_i
      end

      def normalize_item_index(item_index)
        return 0 if item_index.nil?
        return item_index if item_index.is_a?(Integer)

        raise ArgumentError, "item_index must be an Integer"
      end

      def credential_id_for(slot)
        credential = @credentials[slot.to_s]
        credential["id"].to_s if credential
      end

      def declared_credential_slot?(slot)
        credential_definition(slot).present?
      end

      def credential_type_allowed?(slot, credential_type)
        credential_types = NodeData.credential_types_for(credential_definition(slot))
        credential_types.include?(credential_type.to_s)
      end

      def credential_definition(slot)
        @credential_schema.find { |definition| definition["name"] == slot.to_s }
      end

      def code_runner
        @code_runner ||=
          CodeRunner.new(
            input_items: input_items,
            parameters: @parameters,
            input_context: -> { input_context },
            resolver_context: @resolver_context,
            user: @user,
            vars: @vars,
            flow_context: @flow_context,
            runtime_state: @runtime_state,
          )
      end

      def parameter_resolver
        @parameter_resolver ||=
          ParameterResolver.new(
            parameters: @parameters,
            property_schema: @property_schema,
            resolver: @resolver,
            input_items: input_items,
            runtime_state: @runtime_state,
          )
      end
    end
  end
end
