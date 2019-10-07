# frozen_string_literal: true

module DiscourseAutomation
  class PlansController < ::Admin::AdminController
    before_action :fetch_plan, only: %i[update destroy]

    def create
      plan = Plan.new(plan_params)
      plan.save!
      serializer = PlanSerializer.new(plan)
      render_json_dump(serializer)
    end

    def update
      @plan.update!(plan_params)
      serializer = PlanSerializer.new(@plan)
      render_json_dump(serializer)
    end

    def destroy
      @plan.destroy
      render json: success_json
    end

    private

    def fetch_plan
      @plan = Plan.find(params[:id])
    end

    def plan_params
      @plan_params ||= begin
        plannable = Plannable[params[:plan][:identifier]]

        options = {}
        plannable[:fields].each do |key, value|
          options[key] = [:value, :use_provided]
        end

        plan_params = params
          .require(:plan)
          .permit(
            :workflow_id,
            :identifier,
            :delay,
            options: [options]
          )

        plan_params
      end
    end
  end
end
