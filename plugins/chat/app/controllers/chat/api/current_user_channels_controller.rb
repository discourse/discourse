# frozen_string_literal: true

class Chat::Api::CurrentUserChannelsController < Chat::ApiController
  def index
    Chat::ListUserChannels.call do
      on_success do
        render_serialized(
          result.structured,
          Chat::ChannelIndexSerializer,
          root: false,
          post_allowed_category_ids: result.post_allowed_category_ids,
        )
      end
      on_failure { render(json: failed_json, status: 422) }
    end
  end
end
