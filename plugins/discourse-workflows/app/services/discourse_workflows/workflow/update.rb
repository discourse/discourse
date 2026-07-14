# frozen_string_literal: true

module DiscourseWorkflows
  class Workflow::Update
    include Service::Base

    NOT_PROVIDED = Object.new.freeze

    params do
      attribute :workflow_id, :integer
      attribute :name, default: -> { NOT_PROVIDED }
      attribute :error_workflow_id, default: -> { NOT_PROVIDED }
      attribute :timezone, default: -> { NOT_PROVIDED }
      attribute :static_data, default: -> { NOT_PROVIDED }
      attribute :nodes
      attribute :connections
      attribute :autosaved, :boolean, default: false

      validates :workflow_id, presence: true
      validates :name, presence: true, length: { maximum: 100 }, if: :name_provided?
      validate :timezone_is_valid
      validate :static_data_is_valid_map

      def updatable_attributes
        attrs = {}
        attrs[:name] = name if name_provided?
        attrs[:error_workflow_id] = error_workflow_id if error_workflow_id_provided?
        attrs[:static_data] = static_data if static_data_provided?
        attrs
      end

      def name_provided?
        name != NOT_PROVIDED
      end

      def error_workflow_id_provided?
        error_workflow_id != NOT_PROVIDED
      end

      def timezone_provided?
        timezone != NOT_PROVIDED
      end

      def static_data_provided?
        static_data != NOT_PROVIDED
      end

      def graph_data_provided?
        !nodes.nil? || !connections.nil?
      end

      def timezone_is_valid
        return if !timezone_provided? || timezone.blank?
        return if WorkflowTimezone.valid?(timezone)

        errors.add(:timezone, :invalid)
      end

      def static_data_is_valid_map
        return unless static_data_provided?
        return if DiscourseWorkflows::Workflow.valid_static_data_map?(static_data)

        errors.add(:static_data, :invalid)
      end
    end

    policy :can_manage_workflows, class_name: Policy::CanManageWorkflows

    lock(:workflow_id) do
      model :workflow
      model :previous_versioned_payload, :capture_versioned_payload

      transaction do
        model :workflow, :update_workflow
        model :workflow, :save_workflow
        only_if(:graph_data_provided) do
          step :populate_graph
          only_if(:versioned_payload_changed) do
            model :workflow_version, :snapshot_workflow
            step :index_dependencies
          end
        end
      end
    end

    step :expire_workflow_caches

    private

    def fetch_workflow(params:)
      DiscourseWorkflows::Workflow.find_by(id: params.workflow_id)
    end

    def capture_versioned_payload(workflow:)
      workflow.versioned_payload
    end

    def graph_data_provided(params:)
      params.graph_data_provided?
    end

    def versioned_payload_changed(workflow:, previous_versioned_payload:)
      workflow.versioned_payload != previous_versioned_payload
    end

    def update_workflow(workflow:, params:, guardian:)
      attrs = params.updatable_attributes
      attrs[:settings] = settings_with_timezone(workflow, params) if params.timezone_provided?
      workflow.assign_attributes(**attrs, updated_by: guardian.user)
      workflow
    end

    def save_workflow(workflow:)
      workflow.save
      workflow
    end

    def populate_graph(workflow:, params:)
      result =
        Workflow::Action::PopulateGraph.call(
          workflow:,
          nodes_data: params.nodes || [],
          connections_data: params.connections || {},
        )
      fail!(workflow.errors.full_messages) if result == false
    end

    def snapshot_workflow(workflow:, params:, guardian:)
      workflow.snapshot!(user: guardian.user, autosaved: params.autosaved)
    end

    def index_dependencies(workflow:, workflow_version:)
      DiscourseWorkflows::WorkflowDependencyIndexer.call(workflow, version: workflow_version)
    end

    def settings_with_timezone(workflow, params)
      settings = (workflow.settings || {}).dup
      if params.timezone.present?
        settings["timezone"] = params.timezone
      else
        settings.delete("timezone")
      end
      settings
    end

    def expire_workflow_caches
      Workflow::Action::ExpireCaches.call
    end
  end
end
