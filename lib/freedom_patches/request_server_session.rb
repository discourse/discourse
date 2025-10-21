# frozen_string_literal: true

module RequestServerSession
  def server_session
    session[:server_session_id] ||= (session.delete(:secure_session_id) || SecureRandom.hex)
    ServerSession.new(session[:server_session_id])
  end
end

Rack::Request::Helpers.prepend(RequestServerSession)
