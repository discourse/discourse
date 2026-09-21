# frozen_string_literal: true

module DiscourseWorkflows
  class NodePacksController < ::Admin::AdminController
    requires_plugin DiscourseWorkflows::PLUGIN_NAME

    def index
      NodePack::List.call(service_params) do |result|
        on_success do |node_packs:, total_rows:, load_more_url:|
          identifiers = node_packs.flat_map { |pack| pack.definitions.map(&:identifier) }
          usage_query = NodePacks::UsageQuery.new(identifiers)
          serialized =
            node_packs.map do |pack|
              pack_identifiers = pack.definitions.map(&:identifier)
              NodePackSerializer.new(
                pack,
                root: false,
                scope: guardian,
                usage_count: usage_query.workflow_usage_count(pack_identifiers),
              ).as_json
            end
          render json: { node_packs: serialized, meta: { total_rows:, load_more_url: }.compact }
        end
        on_failed_policy(:can_manage_workflows) { raise Discourse::InvalidAccess }
        on_failure { render json: failed_json, status: :unprocessable_entity }
      end
    end

    def show
      NodePack::Show.call(
        service_params.deep_merge(params: { node_pack_id: params[:id] }),
      ) do |result|
        on_success { |node_pack:| render json: { node_pack: detail_json(node_pack) } }
        on_model_not_found(:node_pack) { raise Discourse::NotFound }
        on_failed_policy(:can_manage_workflows) { raise Discourse::InvalidAccess }
      end
    end

    def preview
      NodePack::Preview.call(service_params) do |result|
        on_success { |preview:| render json: { preview: } }
        on_failed_policy(:can_manage_workflows) { raise Discourse::InvalidAccess }
        on_failed_contract { |contract| render_contract_errors(contract) }
        on_failure do
          render json:
                   failed_json.merge(type: "invalid_manifest", errors: result[:manifest_errors]),
                 status: :unprocessable_entity
        end
      end
    end

    def create
      NodePack::Install.call(service_params) do |result|
        on_success do |node_pack:, **success|
          install_result = success[:result]
          render json: {
                   node_pack: detail_json(node_pack.reload),
                   result: install_result,
                 },
                 status: install_result == "unchanged" ? :ok : :created
        end
        on_failed_policy(:can_manage_workflows) { raise Discourse::InvalidAccess }
        on_failed_policy(:destinations_approved) do
          render_install_error(result, :unprocessable_entity)
        end
        on_failed_contract { |contract| render_contract_errors(contract) }
        on_failure do
          render_install_error(
            result,
            conflict_error?(result[:error_type]) ? :conflict : :unprocessable_entity,
          )
        end
      end
    end

    def update
      NodePack::Update.call(
        service_params.deep_merge(params: { node_pack_id: params[:id] }),
      ) do |result|
        on_success { |node_pack:| render json: { node_pack: detail_json(node_pack.reload) } }
        on_model_not_found(:node_pack) { raise Discourse::NotFound }
        on_failed_policy(:can_manage_workflows) { raise Discourse::InvalidAccess }
        on_failed_contract { |contract| render_contract_errors(contract) }
      end
    end

    def destroy
      NodePack::Remove.call(
        service_params.deep_merge(params: { node_pack_id: params[:id] }),
      ) do |result|
        on_success { head :no_content }
        on_model_not_found(:node_pack) { raise Discourse::NotFound }
        on_failed_policy(:can_manage_workflows) { raise Discourse::InvalidAccess }
        on_failed_policy(:not_in_use) do
          render json:
                   failed_json.merge(
                     type: "node_pack_in_use",
                     referencing_workflows: result[:referencing_workflows],
                     active_executions: result[:active_executions],
                   ),
                 status: :conflict
        end
      end
    end

    def export
      NodePack::Show.call(
        service_params.deep_merge(params: { node_pack_id: params[:id] }),
      ) do |result|
        on_success do |node_pack:|
          send_data NodePacks::CanonicalJson.dump(node_pack.manifest),
                    type: "application/json",
                    disposition: "attachment",
                    filename: "#{node_pack.key}-#{node_pack.version}.json"
        end
        on_model_not_found(:node_pack) { raise Discourse::NotFound }
        on_failed_policy(:can_manage_workflows) { raise Discourse::InvalidAccess }
      end
    end

    private

    def detail_json(node_pack)
      identifiers = node_pack.definitions.map(&:identifier)
      query = NodePacks::UsageQuery.new(identifiers)
      NodePackDetailSerializer.new(
        node_pack,
        root: false,
        scope: guardian,
        usage: query.workflows,
        node_usage_counts: query.node_usage_counts,
        active_executions: query.active_executions,
      ).as_json
    end

    def render_install_error(result, status)
      render json:
               failed_json.merge(
                 type: result[:error_type] || "destinations_not_approved",
                 errors: result[:manifest_errors],
                 missing: result[:missing],
                 installed_version: result[:installed_version],
                 nodes: result[:nodes],
               ).compact,
             status:
    end

    def render_contract_errors(contract)
      render json: failed_json.merge(errors: contract.errors.full_messages), status: :bad_request
    end

    def conflict_error?(type)
      %w[revision_conflict downgrade_not_allowed definition_conflict].include?(type)
    end
  end
end
