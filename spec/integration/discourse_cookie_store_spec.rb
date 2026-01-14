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
end
