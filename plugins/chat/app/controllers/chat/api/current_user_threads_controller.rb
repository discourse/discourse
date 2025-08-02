# frozen_string_literal: true

class Chat::Api::CurrentUserThreadsController < Chat::ApiController
  def index
    ::Chat::LookupUserThreads.call(service_params) do
      on_success do |threads:, tracking:, memberships:, load_more_url:, participants:|
        render_serialized(
          ::Chat::ThreadsView.new(
            user: guardian.user,
            threads_participants: participants,
            channel: nil,
            threads:,
            tracking:,
            memberships:,
            load_more_url:,
          ),
          ::Chat::ThreadListSerializer,
          root: false,
        )
      end
      on_failed_contract do |contract|
        render(json: failed_json.merge(errors: contract.errors.full_messages), status: 400)
      end
      on_model_not_found(:threads) { render json: success_json.merge(threads: []) }
      on_failure { render(json: failed_json, status: 422) }
    end
  end
end
