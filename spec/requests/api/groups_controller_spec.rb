# frozen_string_literal: true

RSpec.describe "JSON:API groups", type: :request do
  fab!(:admin)
  fab!(:group) { Fabricate(:group, visibility_level: Group.visibility_levels[:owners]) }

  let(:user) { admin }
  let(:id) { group.id }
  let(:headers) { { "HTTP_API_VERSION" => JsonApiKit::Timeline.current.to_s } }

  before do
    sign_in(user)
    get("/api/groups/#{id}", headers:)
  end

  describe "GET /show" do
    it "returns the group to an admin" do
      expect(JSON.parse(response.body).fetch("data")).to include(
        "type" => "groups",
        "id" => group.id.to_s,
        "attributes" => {
          "name" => group.name,
        },
      )
    end

    context "when the user is not an admin" do
      fab!(:visitor, :user)

      let(:user) { visitor }

      it { expect(response).to have_http_status(:forbidden) }
    end

    context "when the group does not exist" do
      let(:id) { Group.maximum(:id) + 1 }

      it { expect(response).to have_http_status(:not_found) }
    end
  end
end
