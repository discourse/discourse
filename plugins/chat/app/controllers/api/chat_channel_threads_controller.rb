# frozen_string_literal: true

class Chat::Api::ChatChannelThreadsController < Chat::Api
  def show
    params.permit(:thread_id, :channel_id)
    with_service(Chat::Service::LookupThread) do
      on_success { render_serialized(result.thread, ChatThreadSerializer, root: "thread") }
      on_failed_policy(:threaded_discussions_enabled) { raise Discourse::NotFound }
      on_failed_policy(:threading_enabled_for_channel) { raise Discourse::NotFound }
    end
  end
end
