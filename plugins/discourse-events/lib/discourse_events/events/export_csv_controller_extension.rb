# frozen_string_literal: true

module DiscourseEvents
  module Events
    module ExportCsvControllerExtension
      def export_entity
        if post_event_export? && ensure_can_export_post_event
          Jobs.enqueue(
            :export_csv_file,
            entity: export_params[:entity],
            user_id: current_user.id,
            args: export_params[:args],
          )
          StaffActionLogger.new(current_user).log_entity_export(export_params[:entity])
          render json: success_json
        else
          super
        end
      end

      private

      def export_params
        if post_event_export?
          @_export_params ||=
            begin
              params.require(:entity)
              params.permit(:entity, args: %i[id]).to_h
            end
        else
          super
        end
      end

      def post_event_export?
        %w[post_event event_registrations].include?(params[:entity])
      end

      def ensure_can_export_post_event
        return if !SiteSetting.discourse_post_event_enabled

        post_event = DiscourseEvents::Events::Event.find(export_params[:args][:id])
        post_event && guardian.can_export_entity?(params[:entity], nil, export_params[:args])
      end
    end
  end
end
