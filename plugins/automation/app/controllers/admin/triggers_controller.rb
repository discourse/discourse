# frozen_string_literal: true

module DiscourseAutomation
  class TriggersController < ::Admin::AdminController
    before_action :fetch_trigger, only: %i[destroy update]

    def create
      trigger = Trigger.new(trigger_params)
      trigger.save!
      serializer = TriggerSerializer.new(trigger)
      render_json_dump(serializer)
    end

    def update
      @trigger.update!(trigger_params)
      serializer = TriggerSerializer.new(@trigger)
      render_json_dump(serializer)
    end

    def destroy
      @trigger.destroy
      render json: success_json
    end

    private

    def fetch_trigger
      @trigger = Trigger.find(params[:id])
    end

    def trigger_params
      @trigger_params ||= begin
        triggerable = Triggerable[params[:trigger][:identifier]]

        options = {}
        triggerable[:fields].each do |key, value|
          options[key] = [:value, :use_provided]
        end

        trigger_params = params
          .require(:trigger)
          .permit(
            :workflow_id,
            :identifier,
            options: [options]
          )

        trigger_params
      end
    end
  end
end
