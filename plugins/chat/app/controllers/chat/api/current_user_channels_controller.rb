# frozen_string_literal: true

class Chat::Api::CurrentUserChannelsController < Chat::ApiController
  def index
    Chat::ListUserChannels.call(service_params) do
      on_success do |structured:, post_allowed_category_ids:|
        render_serialized(
          structured,
          Chat::ChannelIndexSerializer,
          root: false,
          post_allowed_category_ids: post_allowed_category_ids,
        )
      end
      on_failure { render(json: failed_json, status: 422) }
    end
  end
end
