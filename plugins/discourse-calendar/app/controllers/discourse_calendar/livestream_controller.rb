# frozen_string_literal: true

module DiscourseCalendar
  class LivestreamController < ::ApplicationController
    requires_plugin DiscourseCalendar::PLUGIN_NAME
    requires_login

    def signature
      DiscourseCalendar::Livestream::PrepareZoomJoin.call(
        service_params.deep_merge(params: { topic_id: params[:topic_id] }),
      ) do
        on_success do |sdk_key:, signature:, meeting_number:, password:, user_name:, user_email:, leave_url:|
          render json: {
                   sdk_key: sdk_key,
                   signature: signature,
                   meeting_number: meeting_number,
                   password: password,
                   user_name: user_name,
                   user_email: user_email,
                   leave_url: leave_url,
                 }
        end

        on_model_not_found(:topic) { raise Discourse::NotFound }
        on_failed_policy(:can_see_topic) { raise Discourse::NotFound }
        on_failed_contract { raise Discourse::InvalidParameters }
        on_failure { raise Discourse::NotFound }
      end
    end
  end
end
