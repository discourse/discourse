# frozen_string_literal: true

RSpec.describe "multisite", type: %i[multisite request] do
  it "works" do
    get "http://test.localhost/session/csrf.json"
    expect(response.status).to eq(200)
    cookie = CGI.escape(response.cookies["_forum_session"])
    id1 = session["session_id"]

    get "http://test.localhost/session/csrf.json",
        headers: {
          "Cookie" => "_forum_session=#{cookie};",
        }
    expect(response.status).to eq(200)
    id2 = session["session_id"]

    expect(id1).to eq(id2)

    get "http://test2.localhost/session/csrf.json",
        headers: {
          "Cookie" => "_forum_session=#{cookie};",
        }
    expect(response.status).to eq(200)
    id3 = session["session_id"]

    # Session cookie was rejected and rotated
    expect(id2).not_to eq(id3)
  end
end
