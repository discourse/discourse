# frozen_string_literal: true

class Chat::Api::ChannelThreadsController < Chat::ApiController
  def index
    ::Chat::LookupChannelThreads.call(service_params) do
      on_success do |threads:, channel:, tracking:, memberships:, load_more_url:, participants:|
        render_serialized(
          ::Chat::ThreadsView.new(
            user: guardian.user,
            threads_participants: participants,
            threads:,
            channel:,
            tracking:,
            memberships:,
            load_more_url:,
          ),
          ::Chat::ThreadListSerializer,
          root: false,
        )
      end
      on_failed_policy(:threading_enabled_for_channel) { raise Discourse::NotFound }
      on_failed_policy(:can_view_channel) { raise Discourse::InvalidAccess }
      on_model_not_found(:channel) { raise Discourse::NotFound }
      on_model_not_found(:threads) { render json: success_json.merge(threads: []) }
      on_failure { render(json: failed_json, status: 422) }
      on_failed_contract do |contract|
        render(json: failed_json.merge(errors: contract.errors.full_messages), status: 400)
      end
    end
  end

  def show
    ::Chat::LookupThread.call(service_params) do
      on_success do |thread:, membership:, participants:|
        render_serialized(
          thread,
          ::Chat::ThreadSerializer,
          root: "thread",
          include_thread_preview: true,
          include_thread_original_message: true,
          membership:,
          participants:,
        )
      end
      on_failed_policy(:invalid_access) { raise Discourse::InvalidAccess }
      on_failed_policy(:threading_enabled_for_channel) { raise Discourse::NotFound }
      on_model_not_found(:thread) { raise Discourse::NotFound }
      on_failure { render(json: failed_json, status: 422) }
      on_failed_contract do |contract|
        render(json: failed_json.merge(errors: contract.errors.full_messages), status: 400)
      end
    end
  end

  def update
    ::Chat::UpdateThread.call(service_params) do
      on_failed_policy(:threading_enabled_for_channel) { raise Discourse::NotFound }
      on_failed_policy(:can_view_channel) { raise Discourse::InvalidAccess }
      on_failed_policy(:can_edit_thread) { raise Discourse::InvalidAccess }
      on_model_not_found(:thread) { raise Discourse::NotFound }
      on_failed_step(:update) do |step|
        render json: failed_json.merge(errors: [step.error]), status: 422
      end
      on_success { render(json: success_json) }
      on_failure { render(json: failed_json, status: 422) }
      on_failed_contract do |contract|
        render(json: failed_json.merge(errors: contract.errors.full_messages), status: 400)
      end
    end
  end

  def create
    ::Chat::CreateThread.call(service_params) do
      on_success do |thread:|
        render_serialized(
          thread,
          ::Chat::ThreadSerializer,
          root: false,
          include_thread_original_message: true,
        )
      end
      on_failed_contract do |contract|
        render(json: failed_json.merge(errors: contract.errors.full_messages), status: 400)
      end
      on_model_not_found(:channel) { raise Discourse::NotFound }
      on_failed_policy(:can_view_channel) { raise Discourse::InvalidAccess }
      on_failed_policy(:threading_enabled_for_channel) { raise Discourse::NotFound }
      on_model_errors(:thread) do |model|
        render json: failed_json.merge(errors: [model.errors.full_messages.join(", ")]), status: 422
      end
      on_failure { render(json: failed_json, status: 422) }
    end
  end
end
