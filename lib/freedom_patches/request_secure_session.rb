# frozen_string_literal: true

module RequestSecureSession
  def secure_session
    SecureSession.new(session[:secure_session_id] ||= SecureRandom.hex)
  end
end

Rack::Request::Helpers.prepend(RequestSecureSession)
