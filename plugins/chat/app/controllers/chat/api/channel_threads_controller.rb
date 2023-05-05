# frozen_string_literal: true

class Chat::Api::ChannelThreadsController < Chat::ApiController
  def index
    with_service(::Chat::LookupChannelThreads) do
      on_success do
        render_serialized(
          Chat::ThreadsView.new(
            user: guardian.user,
            threads: result.threads,
            channel: result.channel,
          ),
          ::Chat::ThreadIndexSerializer,
          root: false,
        )
      end
      on_failed_policy(:threaded_discussions_enabled) { raise Discourse::NotFound }
      on_failed_policy(:threading_enabled_for_channel) { raise Discourse::NotFound }
      on_model_not_found(:channel) { raise Discourse::NotFound }
      on_model_not_found(:threads) { render json: success_json }
    end
  end

  def show
    with_service(::Chat::LookupThread) do
      on_success { render_serialized(result.thread, ::Chat::ThreadSerializer, root: "thread") }
      on_failed_policy(:threaded_discussions_enabled) { raise Discourse::NotFound }
      on_failed_policy(:threading_enabled_for_channel) { raise Discourse::NotFound }
      on_model_not_found(:thread) { raise Discourse::NotFound }
    end
  end
end
