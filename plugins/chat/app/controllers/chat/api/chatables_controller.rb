# frozen_string_literal: true

class Chat::Api::ChatablesController < Chat::ApiController
  before_action :ensure_logged_in

  def index
    with_service(::Chat::SearchChatable) do
      on_success { render_serialized(result, ::Chat::ChatablesSerializer, root: false) }
    end
  end
end
