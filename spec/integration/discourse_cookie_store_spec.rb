# frozen_string_literal: true

describe ActionDispatch::Session::DiscourseCookieStore, type: :request do
  it "only writes session cookie when changed" do
    get "/session/csrf.json"
    expect(response.status).to eq(200)
    expect(response.cookies["_forum_session"]).to be_present
    csrf_token = session[:_csrf_token]
    expect(csrf_token).to be_present

    get "/session/csrf.json"
    expect(response.status).to eq(200)
    expect(response.cookies["_forum_session"]).not_to be_present
    expect(session[:_csrf_token]).to eq(csrf_token)
  end

  describe "Cookie overflow" do
    context "when cookie size exceeds limit" do
      let(:fake_logger) { FakeLogger.new }

      before do
        Rails.logger.broadcast_to(fake_logger)
        allow_any_instance_of(ActionController::RequestForgeryProtection).to receive(
          :generate_csrf_token,
        ).and_return(SecureRandom.urlsafe_base64(4097))
      end

      after { Rails.logger.stop_broadcasting_to(fake_logger) }

      it "logs an error" do
        get "/session/csrf.json"
        expect(fake_logger.errors).to include(/Cookie overflow occurred.*"_csrf_token"=>/)
      end
    end
  end
end
