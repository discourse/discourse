# frozen_string_literal: true

module DiscourseCalendar
  class LivestreamController < ::ApplicationController
    requires_plugin DiscourseCalendar::PLUGIN_NAME
    requires_login

    def prepare_zoom_signature
      DiscourseCalendar::Livestream::PrepareZoomJoin.call(
        service_params.deep_merge(params: { topic_id: params[:topic_id] }),
      ) do |result|
        on_success { |zoom_join_payload:| render json: zoom_join_payload }

        on_model_not_found(:topic) { raise Discourse::NotFound }
        on_failed_policy(:can_see_topic) { raise Discourse::NotFound }
        on_failed_contract { raise Discourse::InvalidParameters }
        on_failure { raise Discourse::NotFound }
      end
    end
  end
end
