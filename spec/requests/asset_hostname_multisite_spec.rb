# frozen_string_literal: true

# The asset routes below take the site's hostname as a path segment so a CDN can
# pull every site through a single origin. The segment is unvalidated, so an
# unknown one has to fall back to the default site rather than error.
RSpec.describe "Asset routes with a hostname segment", type: %i[multisite request] do
  it "serves svg sprites for an unknown hostname" do
    get "/svg-sprite/unknown.example.com/svg--#{SecureRandom.hex(20)}.js"

    expect(response.status).to eq(302)
  end

  it "serves svg icons for an unknown hostname" do
    get "/svg-sprite/unknown.example.com/icon/heart.svg"

    expect(response.status).to eq(200)
  end

  it "serves highlight.js for an unknown hostname" do
    get "/highlight-js/unknown.example.com/stale.js"

    expect(response.status).to eq(302)
  end

  it "serves avatars for an unknown hostname" do
    user = Fabricate(:user)

    get "/user_avatar/unknown.example.com/#{user.username}/45/1.png"

    expect(response.status).to eq(200)
  end
end
