# frozen_string_literal: true

class Chat::Api::ChannelThreadsController < Chat::ApiController
  def index
    with_service(::Chat::LookupChannelThreads) do
      on_success do
        render_serialized(
          ::Chat::ThreadsView.new(
            user: guardian.user,
            threads: result.threads,
            channel: result.channel,
            tracking: result.tracking,
            memberships: result.memberships,
            load_more_url: result.load_more_url,
          ),
          ::Chat::ThreadListSerializer,
          root: false,
        )
      end
      on_failed_policy(:threaded_discussions_enabled) { raise Discourse::NotFound }
      on_failed_policy(:threading_enabled_for_channel) { raise Discourse::NotFound }
      on_failed_policy(:can_view_channel) { raise Discourse::InvalidAccess }
      on_model_not_found(:channel) { raise Discourse::NotFound }
      on_model_not_found(:threads) { render json: success_json.merge(threads: []) }
    end
  end

  def show
    with_service(::Chat::LookupThread) do
      on_success do
        render_serialized(
          result.thread,
          ::Chat::ThreadSerializer,
          root: "thread",
          membership: result.membership,
          include_preview: true,
          participants: result.participants,
        )
      end
      on_failed_policy(:threaded_discussions_enabled) { raise Discourse::NotFound }
      on_failed_policy(:threading_enabled_for_channel) { raise Discourse::NotFound }
      on_model_not_found(:thread) { raise Discourse::NotFound }
    end
  end

  def update
    with_service(::Chat::UpdateThread) do
      on_failed_policy(:threaded_discussions_enabled) { raise Discourse::NotFound }
      on_failed_policy(:threading_enabled_for_channel) { raise Discourse::NotFound }
      on_failed_policy(:can_view_channel) { raise Discourse::InvalidAccess }
      on_failed_policy(:can_edit_thread) { raise Discourse::InvalidAccess }
      on_model_not_found(:thread) { raise Discourse::NotFound }
      on_failed_step(:update) do
        render json: failed_json.merge(errors: [result["result.step.update"].error]), status: 422
      end
    end
  end
end
