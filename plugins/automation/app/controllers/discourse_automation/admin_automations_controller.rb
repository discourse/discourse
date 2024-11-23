# frozen_string_literal: true

module DiscourseAutomation
  class AdminAutomationsController < ::Admin::AdminController
    requires_plugin DiscourseAutomation::PLUGIN_NAME

    def index
      automations = DiscourseAutomation::Automation.order(:name).all
      serializer =
        ActiveModel::ArraySerializer.new(
          automations,
          each_serializer: DiscourseAutomation::AutomationSerializer,
          root: "automations",
        ).as_json
      render_json_dump(serializer)
    end

    def show
      automation = DiscourseAutomation::Automation.find(params[:id])
      render_serialized_automation(automation)
    end

    def create
      automation_params = params.require(:automation).permit(:script, :trigger)

      automation =
        DiscourseAutomation::Automation.new(
          automation_params.merge(last_updated_by_id: current_user.id),
        )

      if automation.scriptable&.forced_triggerable
        automation.trigger = automation.scriptable.forced_triggerable[:triggerable].to_s
      end

      automation.save!

      render_serialized_automation(automation)
    end

    def update
      params.require(:automation)

      automation = DiscourseAutomation::Automation.find(params[:id])
      if automation.scriptable.forced_triggerable
        params[:trigger] = automation.scriptable.forced_triggerable[:triggerable].to_s
      end

      attributes =
        request.parameters[:automation].slice(:name, :id, :script, :trigger, :enabled).merge(
          last_updated_by_id: current_user.id,
        )

      if automation.trigger != params[:automation][:trigger]
        params[:automation][:fields] = []
        attributes[:enabled] = false
        automation.fields.destroy_all
      end

      if automation.script != params[:automation][:script]
        attributes[:trigger] = nil
        params[:automation][:fields] = []
        attributes[:enabled] = false
        automation.fields.destroy_all
        automation.tap { |r| r.assign_attributes(attributes) }.save!(validate: false)
      else
        Array(params[:automation][:fields])
          .reject(&:empty?)
          .each do |field|
            automation.upsert_field!(
              field[:name],
              field[:component],
              field[:metadata],
              target: field[:target],
            )
          end

        automation.tap { |r| r.assign_attributes(attributes) }.save!
      end

      render_serialized_automation(automation)
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
