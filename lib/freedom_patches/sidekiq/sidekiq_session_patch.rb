# frozen_string_literal: true

module SidekiqSessionPatch
  # Original
  # RACK_SESSION = "rack.session"
  # def session
  #   env[RACK_SESSION]
  # end
  def session
    ActionDispatch::Request::Session.find(request)
  end
end
