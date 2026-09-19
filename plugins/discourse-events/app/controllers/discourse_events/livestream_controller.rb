# frozen_string_literal: true

module DiscourseEvents
  class LivestreamController < ::ApplicationController
    requires_plugin DiscourseEvents::PLUGIN_NAME
    requires_login

    skip_before_action :check_xhr, only: [:zoom_frame]

    # The frame is the only thing that loads the SDK, so this is the one place
    # the version is stated. Bump it to adopt a newer release.
    # https://developers.zoom.us/docs/meeting-sdk/web/get-started/
    ZOOM_SDK_VERSION = "6.2.0"
    ZOOM_SDK_CDN = "https://source.zoom.us"

    # Hosts Zoom's full-page meeting view for embedding. The meeting sizes
    # itself to the window it is in, so it is given a window of its own to
    # render into and the page around it stays free for other content.
    def zoom_frame
      topic = Topic.find_by(id: params[:topic_id])

      # Not found rather than forbidden, and the same for a topic that is not
      # there as for one that may not be seen: the signature this page goes on
      # to ask for answers that way too, and between them they should not say
      # more about a topic than the other does.
      raise Discourse::NotFound if topic.blank? || !guardian.can_see?(topic)
      raise Discourse::NotFound if !SiteSetting.livestream_zoom_enabled

      # The page is served outside the app, so it has none of the site's colors
      # to hand. Only the one the button is built from is needed.
      @accent_color = "##{ColorScheme.hex_for_name("tertiary") || "0088cc"}"

      signature_params = { topic_id: topic.id }
      # TODO (martin) showzoom is for testing only, remove before merge
      signature_params[:ignore_timeframe] = true if params[:showzoom].present?

      @config = {
        cdn: ZOOM_SDK_CDN,
        sdkVersion: ZOOM_SDK_VERSION,
        signatureUrl: "#{frame_base_path}/signature.json?#{signature_params.to_query}",
        # Zoom navigates this window when the user leaves, which is the only
        # notice the page around it gets that the meeting is over.
        leaveUrl:
          "#{Discourse.base_url_no_prefix}#{frame_base_path}/frame?topic_id=#{topic.id}&left=1",
        hasLeft: params[:left].present?,
      }

      render layout: false
    end

    def prepare_zoom_signature
      DiscourseEvents::Livestream::PrepareZoomJoin.call(
        service_params.deep_merge(params: { topic_id: params[:topic_id] }),
      ) do |result|
        on_success { |zoom_join_payload:| render json: zoom_join_payload }

        on_model_not_found(:topic) { raise Discourse::NotFound }
        on_failed_policy(:can_see_topic) { raise Discourse::NotFound }
        on_failed_contract { raise Discourse::InvalidParameters }
        on_failure { raise Discourse::NotFound }
      end
    end

    private

    def frame_base_path
      "#{Discourse.base_path}/discourse-calendar/livestream/zoom"
    end
  end
end
