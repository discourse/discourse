# frozen_string_literal: true

RSpec.describe "multisite", type: %i[multisite request] do
  let!(:first_host) { get "http://test.localhost/session/csrf.json" }

  it "works" do
    get "http://test.localhost/session/csrf.json"
    expect(response).to have_http_status :ok
    cookie = CGI.escape(response.cookies["_forum_session"])
    id1 = session["session_id"]

    get "http://test.localhost/session/csrf.json",
        headers: {
          "Cookie" => "_forum_session=#{cookie};",
        }
    expect(response).to have_http_status :ok
    id2 = session["session_id"]

    expect(id1).to eq(id2)

    get "http://test2.localhost/session/csrf.json",
        headers: {
          "Cookie" => "_forum_session=#{cookie};",
        }
    expect(response).to have_http_status :ok
    id3 = session["session_id"]

    # Session cookie was rejected and rotated
    expect(id2).not_to eq(id3)
  end

  describe "Cookies rotator" do
    let!(:rotations) { request.cookies_rotations }
    let(:second_host) { get "http://test2.localhost/session/csrf.json" }
    let(:global_rotations) { Rails.application.config.action_dispatch.cookies_rotations }

    it "adds different rotations for different hosts" do
      first_host
      expect(request.cookies_rotations).to have_attributes signed: rotations.signed,
                      encrypted: rotations.encrypted

      second_host
      expect(request.cookies_rotations).not_to have_attributes signed: rotations.signed,
                      encrypted: rotations.encrypted
    end

    it "doesn't change global rotations" do
      second_host
      expect(global_rotations).to have_attributes signed: [], encrypted: []
    end
  end
end
