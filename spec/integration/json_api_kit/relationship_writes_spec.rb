# frozen_string_literal: true

module JsonApiKitRelationshipWritesSpec
  class GroupResource < JsonApiKit::Resource
    model Group
    type :groups

    has_many :users, resource: ::UserResource, writable: true
    has_one :smtp_updated_by, resource: ::UserResource, writable: true
  end

  class RenameUsers < JsonApiKit::VersionChange
    version "2026-09-01"
    description "People become users."

    renamed_type from: :people, to: :users
  end

  class GroupUsersController < JsonApiKit::RelationshipsController
    resource GroupResource
    relationship :users

    def create
      group.bulk_add(user_ids)
      render_linkage_of(group.users)
    end

    def destroy
      group.bulk_remove(user_ids)
      head :no_content
    end

    def update
      group.user_ids = user_ids
      head :no_content
    end

    private

    def write_params = @write_params ||= service_params.fetch(:params)
    def group = @group ||= Group.find(write_params.fetch(:id))
    def user_ids = write_params.fetch(:user_ids)
  end

  class GroupSmtpUpdatedByController < JsonApiKit::RelationshipsController
    resource GroupResource
    relationship :smtp_updated_by

    def update
      group.update!(smtp_updated_by_id: write_params.fetch(:smtp_updated_by_id))
      render_linkage_of(group.smtp_updated_by)
    end

    private

    def write_params = @write_params ||= service_params.fetch(:params)
    def group = @group ||= Group.find(write_params.fetch(:id))
  end
end

RSpec.describe "JSON:API standalone relationship writes", type: :request do
  fab!(:member, :user)
  fab!(:other_user, :user)
  fab!(:group) { Fabricate(:group, users: [member], smtp_updated_by: member) }

  let(:version) { "2026-09-01" }
  let(:type) { "users" }
  let(:headers) do
    { "HTTP_API_VERSION" => version, "CONTENT_TYPE" => JsonApiKit::MediaType::JSON_API }
  end
  let(:version_changes) do
    JsonApiKit::VersionChanges.new([JsonApiKitRelationshipWritesSpec::RenameUsers.new(__FILE__)])
  end
  let(:linkage) { JSON.parse(response.body).fetch("data") }

  before do
    freeze_time(Date.new(2026, 9, 2))
    allow(JsonApiKit::VersionChanges).to receive(:core).and_return(version_changes)
    Rails.application.routes.disable_clear_and_finalize = true
    Rails.application.routes.draw do
      users_path = "/api/groups/:id/relationships/users"
      users_controller = "json_api_kit_relationship_writes_spec/group_users"
      post users_path => "#{users_controller}#create"
      delete users_path => "#{users_controller}#destroy"
      patch users_path => "#{users_controller}#update"

      patch "/api/groups/:id/relationships/smtp-updated-by" =>
              "json_api_kit_relationship_writes_spec/group_smtp_updated_by#update"
    end
    Rails.application.routes.disable_clear_and_finalize = false
  end

  after { Rails.application.reload_routes! }

  def identifier(user) = { "type" => type, "id" => user.id.to_s }

  describe JsonApiKitRelationshipWritesSpec::GroupUsersController do
    let(:path) { "/api/groups/#{group.id}/relationships/users" }
    let(:payload) { { data: [identifier(other_user)] }.to_json }

    describe "#create" do
      it "adds the requested member to the group", :aggregate_failures do
        post(path, params: payload, headers:)

        expect(response).to have_http_status(:ok)
        expect(group.reload.user_ids).to contain_exactly(member.id, other_user.id)
        expect(linkage).to contain_exactly(identifier(member), identifier(other_user))
      end

      context "when the client pins a version before the target type rename" do
        let(:version) { JsonApiKit::Timeline::FIRST_RELEASE.to_s }
        let(:type) { "people" }

        it "adds the member using the previous type name", :aggregate_failures do
          post(path, params: payload, headers:)

          expect(response).to have_http_status(:ok)
          expect(group.reload.user_ids).to contain_exactly(member.id, other_user.id)
          expect(linkage).to contain_exactly(identifier(member), identifier(other_user))
        end
      end
    end

    describe "#destroy" do
      before { group.users << other_user }

      it "removes only the requested member", :aggregate_failures do
        delete(path, params: payload, headers:)

        expect(response).to have_http_status(:no_content)
        expect(group.reload.user_ids).to contain_exactly(member.id)
      end

      context "when the client pins a version before the target type rename" do
        let(:version) { JsonApiKit::Timeline::FIRST_RELEASE.to_s }
        let(:type) { "people" }

        it "removes the member using the previous type name", :aggregate_failures do
          delete(path, params: payload, headers:)

          expect(response).to have_http_status(:no_content)
          expect(group.reload.user_ids).to contain_exactly(member.id)
        end
      end
    end

    describe "#update" do
      it "replaces the existing member with the new member", :aggregate_failures do
        patch(path, params: payload, headers:)

        expect(response).to have_http_status(:no_content)
        expect(group.reload.user_ids).to contain_exactly(other_user.id)
      end

      context "when the client pins a version before the target type rename" do
        let(:version) { JsonApiKit::Timeline::FIRST_RELEASE.to_s }
        let(:type) { "people" }

        it "replaces the member using the previous type name", :aggregate_failures do
          patch(path, params: payload, headers:)

          expect(response).to have_http_status(:no_content)
          expect(group.reload.user_ids).to contain_exactly(other_user.id)
        end
      end
    end
  end

  describe JsonApiKitRelationshipWritesSpec::GroupSmtpUpdatedByController do
    let(:path) { "/api/groups/#{group.id}/relationships/smtp-updated-by" }
    let(:payload) { { data: identifier(other_user) }.to_json }

    describe "#update" do
      it "replaces the related user", :aggregate_failures do
        patch(path, params: payload, headers:)

        expect(response).to have_http_status(:ok)
        expect(group.reload.smtp_updated_by_id).to eq(other_user.id)
        expect(linkage).to eq(identifier(other_user))
      end

      context "when the payload is null" do
        let(:payload) { { data: nil }.to_json }

        it "clears the related user", :aggregate_failures do
          patch(path, params: payload, headers:)

          expect(response).to have_http_status(:ok)
          expect(group.reload.smtp_updated_by_id).to be_nil
          expect(linkage).to be_nil
        end
      end

      context "when the client pins a version before the target type rename" do
        let(:version) { JsonApiKit::Timeline::FIRST_RELEASE.to_s }
        let(:type) { "people" }

        it "replaces the related user using the previous type name", :aggregate_failures do
          patch(path, params: payload, headers:)

          expect(response).to have_http_status(:ok)
          expect(group.reload.smtp_updated_by_id).to eq(other_user.id)
          expect(linkage).to eq(identifier(other_user))
        end
      end
    end
  end
end
