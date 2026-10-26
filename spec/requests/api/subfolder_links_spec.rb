# frozen_string_literal: true

RSpec.describe "JSON:API links in a subfolder", type: :request do
  fab!(:admin)
  fab!(:group)

  before do
    set_subfolder "/forum"
    sign_in(admin)
  end

  it "keeps the subfolder in resource links" do
    get "/api/groups/#{group.id}",
        headers: {
          "HTTP_API_VERSION" => JsonApiKit::Timeline.current.to_s,
        }

    expect(JSON.parse(response.body).dig("data", "links", "self")).to eq(
      "#{Discourse.base_url}/api/groups/#{group.id}",
    )
  end
end
