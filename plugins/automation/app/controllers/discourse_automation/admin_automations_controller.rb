# frozen_string_literal: true

module DiscourseAutomation
  class AdminAutomationsController < ::Admin::AdminController
    requires_plugin PLUGIN_NAME

    def index
      automations =
        DiscourseAutomation::Automation
          .strict_loading
          .includes(:fields, :pending_automations, :last_updated_by)
          .order(:name)
          .limit(500)
          .all
      serializer =
        ActiveModel::ArraySerializer.new(
          automations,
          each_serializer: DiscourseAutomation::AutomationSerializer,
          root: "automations",
          scope: {
            stats: DiscourseAutomation::Stat.fetch_period_summaries,
          },
        ).as_json
      render_json_dump(serializer)
    end

    def show
      automation =
        DiscourseAutomation::Automation.includes(
          :fields,
          :pending_automations,
          :last_updated_by,
        ).find(params[:id])
      render_serialized_automation(automation)
    end

    def create
      DiscourseAutomation::Create.call(
        params: params.require(:automation).to_unsafe_h,
        guardian:,
      ) do
        on_success { |automation:| render_serialized_automation(automation) }
        on_failed_policy(:can_create_automation) { raise Discourse::InvalidAccess }
        on_failed_contract do |contract|
          render json: failed_json.merge(errors: contract.errors.full_messages),
                 status: :bad_request
        end
        on_failure { raise Discourse::InvalidParameters }
      end
    end

    def update
      DiscourseAutomation::Update.call(
        params: params.require(:automation).to_unsafe_h.merge(automation_id: params[:id]),
        guardian:,
      ) do
        on_success { |automation:| render_serialized_automation(automation) }
        on_model_not_found(:automation) { raise Discourse::NotFound }
        on_failed_policy(:can_update_automation) { raise Discourse::InvalidAccess }
        on_failed_contract do |contract|
          render json: failed_json.merge(errors: contract.errors.full_messages),
                 status: :bad_request
        end
        on_failure { raise Discourse::InvalidParameters }
      end
    end

    def destroy
      DiscourseAutomation::Destroy.call(service_params) do
        on_success { render(json: success_json) }
        on_model_not_found(:automation) { raise Discourse::NotFound }
        on_failed_policy(:can_destroy_automation) { raise Discourse::InvalidAccess }
      end
    end

    private

    def render_serialized_automation(automation)
      serializer =
        DiscourseAutomation::AutomationSerializer.new(automation, root: "automation").as_json
      render_json_dump(serializer)
    end
  end
end
