# frozen_string_literal: true

RSpec.describe DiscourseDataExplorer::QueryGroupRelationshipsController, type: :request do
  fab!(:admin)
  fab!(:first_group, :group)
  fab!(:second_group, :group)
  fab!(:third_group, :group)

  let!(:query) { Fabricate(:query, hidden:) }
  let(:hidden) { false }
  let(:user) { admin }
  let(:path) { "/api/data-explorer/queries/#{query.id}/relationships/groups" }
  let(:headers) do
    {
      "HTTP_API_VERSION" => JsonApiKit::Timeline.current.to_s,
      "CONTENT_TYPE" => JsonApiKit::MediaType::JSON_API,
    }
  end
  let(:requested_groups) { [second_group, third_group] }
  let(:payload) { { data: requested_groups.map { identifier(it) } }.to_json }

  before do
    SiteSetting.data_explorer_enabled = true
    host! Discourse.current_hostname
    sign_in(user)
    query.groups = [first_group, second_group]
  end

  def identifier(group) = { type: "groups", id: group.id.to_s }

  describe "#create" do
    subject(:add_groups) { post(path, params: payload, headers:) }

    it "adds the missing requested groups", :aggregate_failures do
      add_groups

      expect(response).to have_http_status(:no_content)
      expect(response.body).to be_empty
      expect(query.reload.group_ids).to contain_exactly(
        first_group.id,
        second_group.id,
        third_group.id,
      )
    end

    context "when a requested group does not exist" do
      let(:payload) do
        {
          data: [identifier(third_group), { type: "groups", id: Group.maximum(:id).next.to_s }],
        }.to_json
      end

      it "returns not found without changing group access", :aggregate_failures do
        add_groups

        expect(response).to have_http_status(:not_found)
        expect(query.reload.group_ids).to contain_exactly(first_group.id, second_group.id)
      end
    end

    context "when the query is hidden" do
      let(:hidden) { true }

      it "returns not found" do
        add_groups

        expect(response).to have_http_status(:not_found)
      end
    end

    context "when the user is not an admin" do
      fab!(:visitor, :user)

      let(:user) { visitor }

      it "returns forbidden" do
        add_groups

        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe "#update" do
    subject(:replace_groups) { patch(path, params: payload, headers:) }

    it "replaces the query's groups", :aggregate_failures do
      replace_groups

      expect(response).to have_http_status(:no_content)
      expect(response.body).to be_empty
      expect(query.reload.group_ids).to contain_exactly(second_group.id, third_group.id)
    end

    context "when a requested group does not exist" do
      let(:payload) do
        {
          data: [identifier(third_group), { type: "groups", id: Group.maximum(:id).next.to_s }],
        }.to_json
      end

      it "returns not found without changing group access", :aggregate_failures do
        replace_groups

        expect(response).to have_http_status(:not_found)
        expect(query.reload.group_ids).to contain_exactly(first_group.id, second_group.id)
      end
    end
  end

  describe "#destroy" do
    subject(:remove_groups) { delete(path, params: payload, headers:) }

    it "removes only the requested groups", :aggregate_failures do
      remove_groups

      expect(response).to have_http_status(:no_content)
      expect(response.body).to be_empty
      expect(query.reload.group_ids).to contain_exactly(first_group.id)
    end
  end
end
