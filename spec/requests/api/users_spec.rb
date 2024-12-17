# frozen_string_literal: true
require "swagger_helper"

RSpec.describe "users" do
  let(:"Api-Key") { Fabricate(:api_key).key }
  let(:"Api-Username") { "system" }
  let(:admin) { Fabricate(:admin) }

  before do
    SiteSetting.tagging_enabled = true
    Jobs.run_immediately!
    sign_in(admin)
  end

  path "/users.json" do
    post "Creates a user" do
      tags "Users"
      operationId "createUser"
      consumes "application/json"
      # This endpoint requires an api key or the active param is ignored
      parameter name: "Api-Key", in: :header, type: :string, required: true
      parameter name: "Api-Username", in: :header, type: :string, required: true
      expected_request_schema = load_spec_schema("user_create_request")
      parameter name: :params, in: :body, schema: expected_request_schema

      produces "application/json"
      response "200", "user created" do
        expected_response_schema = load_spec_schema("user_create_response")
        schema expected_response_schema

        let(:params) do
          {
            "name" => "user",
            "username" => "user1",
            "email" => "user1@example.com",
            "password" => "13498428e9597cab689b468ebc0a5d33",
            "active" => true,
          }
        end

        it_behaves_like "a JSON endpoint", 200 do
          let(:expected_response_schema) { expected_response_schema }
          let(:expected_request_schema) { expected_request_schema }
        end
      end
    end
  end

  path "/u/{username}.json" do
    get "Get a single user by username" do
      tags "Users"
      operationId "getUser"
      consumes "application/json"
      parameter name: "Api-Key", in: :header, type: :string, required: true
      parameter name: "Api-Username", in: :header, type: :string, required: true
      parameter name: :username, in: :path, type: :string, required: true
      expected_request_schema = nil

      produces "application/json"
      response "200", "user response" do
        expected_response_schema = load_spec_schema("user_get_response")
        schema expected_response_schema

        let(:username) { Fabricate(:user).username }

        it_behaves_like "a JSON endpoint", 200 do
          let(:expected_response_schema) { expected_response_schema }
          let(:expected_request_schema) { expected_request_schema }
        end
      end

      response "200", "user with primary group response" do
        expected_response_schema = load_spec_schema("user_get_response")
        schema expected_response_schema

        let(:username) { Fabricate(:user, primary_group_id: Fabricate(:group).id).username }

        it_behaves_like "a JSON endpoint", 200 do
          let(:expected_response_schema) { expected_response_schema }
          let(:expected_request_schema) { expected_request_schema }
        end
      end
    end

    put "Update a user" do
      tags "Users"
      operationId "updateUser"
      consumes "application/json"

      parameter name: "Api-Key", in: :header, type: :string, required: true
      parameter name: "Api-Username", in: :header, type: :string, required: true
      expected_request_schema = load_spec_schema("user_update_request")
      parameter name: :username, in: :path, type: :string, required: true
      parameter name: :params, in: :body, schema: expected_request_schema

      produces "application/json"
      response "200", "user updated" do
        expected_response_schema = load_spec_schema("user_update_response")
        schema expected_response_schema

        let(:username) { Fabricate(:user).username }
        let(:params) { { "name" => "user" } }

        it_behaves_like "a JSON endpoint", 200 do
          let(:expected_response_schema) { expected_response_schema }
          let(:expected_request_schema) { expected_request_schema }
        end
      end
    end
  end

  path "/u/by-external/{external_id}.json" do
    get "Get a user by external_id" do
      tags "Users"
      operationId "getUserExternalId"
      consumes "application/json"
      parameter name: "Api-Key", in: :header, type: :string, required: true
      parameter name: "Api-Username", in: :header, type: :string, required: true
      parameter name: :external_id, in: :path, type: :string, required: true
      expected_request_schema = nil

      produces "application/json"
      response "200", "user response" do
        expected_response_schema = load_spec_schema("user_get_response")
        schema expected_response_schema

        let(:user) { Fabricate(:user) }
        let(:external_id) { "1" }

        before do
          SiteSetting.discourse_connect_url = "http://someurl.com"
          SiteSetting.enable_discourse_connect = true
          user.create_single_sign_on_record(external_id: "1", last_payload: "")
        end

        it_behaves_like "a JSON endpoint", 200 do
          let(:expected_response_schema) { expected_response_schema }
          let(:expected_request_schema) { expected_request_schema }
        end
      end
    end
  end

  path "/u/by-external/{provider}/{external_id}.json" do
    get "Get a user by identity provider external ID" do
      tags "Users"
      operationId "getUserIdentiyProviderExternalId"
      consumes "application/json"
      parameter name: "Api-Key", in: :header, type: :string, required: true
      parameter name: "Api-Username", in: :header, type: :string, required: true
      parameter name: :provider,
                in: :path,
                type: :string,
                required: true,
                description:
                  "Authentication provider name. Can be found in the provider callback URL: `/auth/{provider}/callback`"
      parameter name: :external_id, in: :path, type: :string, required: true
      expected_request_schema = nil

      produces "application/json"
      response "200", "user response" do
        expected_response_schema = load_spec_schema("user_get_response")
        schema expected_response_schema

        let(:user) { Fabricate(:user) }
        let(:provider) { "google_oauth2" }
        let(:external_id) { "myuid" }

        before do
          SiteSetting.enable_google_oauth2_logins = true
          UserAssociatedAccount.create!(
            user: user,
            provider_uid: "myuid",
            provider_name: "google_oauth2",
          )
        end

        it_behaves_like "a JSON endpoint", 200 do
          let(:expected_response_schema) { expected_response_schema }
          let(:expected_request_schema) { expected_request_schema }
        end
      end
    end
  end

  path "/u/{username}/preferences/avatar/pick.json" do
    put "Update avatar" do
      tags "Users"
      operationId "updateAvatar"
      consumes "application/json"
      expected_request_schema = load_spec_schema("user_update_avatar_request")

      parameter name: :username, in: :path, type: :string, required: true
      parameter name: :params, in: :body, schema: expected_request_schema

      produces "application/json"
      response "200", "avatar updated" do
        expected_response_schema = load_spec_schema("success_ok_response")

        let(:user) { Fabricate(:user, refresh_auto_groups: true) }
        let(:username) { user.username }
        let(:upload) { Fabricate(:upload, user: user) }
        let(:params) { { "upload_id" => upload.id, "type" => "uploaded" } }

        schema(expected_response_schema)

        it_behaves_like "a JSON endpoint", 200 do
          let(:expected_response_schema) { expected_response_schema }
          let(:expected_request_schema) { expected_request_schema }
        end
      end
    end
  end

  path "/u/{username}/preferences/email.json" do
    put "Update email" do
      tags "Users"
      operationId "updateEmail"
      consumes "application/json"
      expected_request_schema = load_spec_schema("user_update_email_request")

      parameter name: :username, in: :path, type: :string, required: true
      parameter name: :params, in: :body, schema: expected_request_schema

      produces "application/json"
      response "200", "email updated" do
        let(:user) { Fabricate(:user) }
        let(:username) { user.username }
        let(:params) { { "email" => "test@example.com" } }

        expected_response_schema = nil

        it_behaves_like "a JSON endpoint", 200 do
          let(:expected_response_schema) { expected_response_schema }
          let(:expected_request_schema) { expected_request_schema }
        end
      end
    end
  end

  path "/u/{username}/preferences/username.json" do
    put "Update username" do
      tags "Users"
      operationId "updateUsername"
      consumes "application/json"
      expected_request_schema = load_spec_schema("user_update_username_request")

      parameter name: :username, in: :path, type: :string, required: true
      parameter name: :params, in: :body, schema: expected_request_schema

      produces "application/json"
      response "200", "username updated" do
        let(:user) { Fabricate(:user) }
        let(:username) { user.username }
        let(:params) { { "new_username" => "#{user.username}1" } }

        expected_response_schema = nil

        it_behaves_like "a JSON endpoint", 200 do
          let(:expected_response_schema) { expected_response_schema }
          let(:expected_request_schema) { expected_request_schema }
        end
      end
    end
  end

  path "/directory_items.json" do
    get "Get a public list of users" do
      tags "Users"
      operationId "listUsersPublic"
      consumes "application/json"
      expected_request_schema = nil

      parameter name: :period,
                in: :query,
                schema: {
                  type: :string,
                  enum: %w[daily weekly monthly quarterly yearly all],
                },
                required: true
      parameter name: :order,
                in: :query,
                schema: {
                  type: :string,
                  enum: %w[
                    likes_received
                    likes_given
                    topic_count
                    post_count
                    topics_entered
                    posts_read
                    days_visited
                  ],
                },
                required: true
      parameter name: :asc, in: :query, schema: { type: :string, enum: ["true"] }
      parameter name: :page, in: :query, type: :integer

      produces "application/json"
      response "200", "directory items response" do
        let(:period) { "weekly" }
        let(:order) { "likes_received" }
        let(:asc) { "true" }
        let(:page) { 0 }

        expected_response_schema = load_spec_schema("users_public_list_response")
        schema(expected_response_schema)

        it_behaves_like "a JSON endpoint", 200 do
          let(:expected_response_schema) { expected_response_schema }
          let(:expected_request_schema) { expected_request_schema }
        end
      end
    end
  end

  path "/admin/users/{id}.json" do
    get "Get a user by id" do
      tags "Users", "Admin"
      operationId "adminGetUser"
      consumes "application/json"
      expected_request_schema = nil

      parameter name: :id, in: :path, type: :integer, required: true

      produces "application/json"
      response "200", "response" do
        let(:id) { Fabricate(:user).id }

        expected_response_schema = load_spec_schema("admin_user_response")
        schema(expected_response_schema)

        it_behaves_like "a JSON endpoint", 200 do
          let(:expected_response_schema) { expected_response_schema }
          let(:expected_request_schema) { expected_request_schema }
        end
      end
    end

    delete "Delete a user" do
      tags "Users", "Admin"
      operationId "deleteUser"
      consumes "application/json"
      expected_request_schema = load_spec_schema("user_delete_request")

      parameter name: :id, in: :path, type: :integer, required: true
      parameter name: :params, in: :body, schema: expected_request_schema

      produces "application/json"
      response "200", "response" do
        let(:id) { Fabricate(:user).id }
        let(:params) do
          {
            "delete_posts" => true,
            "block_email" => false,
            "block_urls" => false,
            "block_ip" => false,
          }
        end

        expected_response_schema = load_spec_schema("user_delete_response")
        schema(expected_response_schema)

        it_behaves_like "a JSON endpoint", 200 do
          let(:expected_response_schema) { expected_response_schema }
          let(:expected_request_schema) { expected_request_schema }
        end
      end
    end
  end

  path "/admin/users/{id}/activate.json" do
    put "Activate a user" do
      tags "Users", "Admin"
      operationId "activateUser"
      consumes "application/json"
      expected_request_schema = nil
      parameter name: :id, in: :path, type: :integer, required: true

      produces "application/json"
      response "200", "response" do
        let(:id) { Fabricate(:user, active: false).id }

        expected_response_schema = load_spec_schema("success_ok_response")
        schema(expected_response_schema)

        it_behaves_like "a JSON endpoint", 200 do
          let(:expected_response_schema) { expected_response_schema }
          let(:expected_request_schema) { expected_request_schema }
        end
      end
    end
  end

  path "/admin/users/{id}/deactivate.json" do
    put "Deactivate a user" do
      tags "Users", "Admin"
      operationId "deactivateUser"
      consumes "application/json"
      expected_request_schema = nil
      parameter name: :id, in: :path, type: :integer, required: true

      produces "application/json"
      response "200", "response" do
        let(:id) { Fabricate(:user).id }

        expected_response_schema = load_spec_schema("success_ok_response")
        schema(expected_response_schema)

        it_behaves_like "a JSON endpoint", 200 do
          let(:expected_response_schema) { expected_response_schema }
          let(:expected_request_schema) { expected_request_schema }
        end
      end
    end
  end

  path "/admin/users/{id}/suspend.json" do
    put "Suspend a user" do
      tags "Users", "Admin"
      operationId "suspendUser"
      consumes "application/json"
      expected_request_schema = load_spec_schema("user_suspend_request")

      parameter name: :id, in: :path, type: :integer, required: true
      parameter name: :params, in: :body, schema: expected_request_schema

      produces "application/json"
      response "200", "response" do
        let(:id) { Fabricate(:user).id }
        let(:params) { { "suspend_until" => "2121-02-22", "reason" => "inactivity" } }

        expected_response_schema = load_spec_schema("user_suspend_response")
        schema(expected_response_schema)

        it_behaves_like "a JSON endpoint", 200 do
          let(:expected_response_schema) { expected_response_schema }
          let(:expected_request_schema) { expected_request_schema }
        end
      end
    end
  end

  path "/admin/users/{id}/silence.json" do
    put "Silence a user" do
      tags "Users", "Admin"
      operationId "silenceUser"
      consumes "application/json"
      expected_request_schema = load_spec_schema("user_silence_request")

      parameter name: :id, in: :path, type: :integer, required: true
      parameter name: :params, in: :body, schema: expected_request_schema

      produces "application/json"
      response "200", "response" do
        let(:id) { Fabricate(:user).id }
        let(:params) { { "reason" => "up to me", "silenced_till" => "2301-08-15" } }

        expected_response_schema = load_spec_schema("user_silence_response")
        schema(expected_response_schema)

        it_behaves_like "a JSON endpoint", 200 do
          let(:expected_response_schema) { expected_response_schema }
          let(:expected_request_schema) { expected_request_schema }
        end
      end
    end
  end

  path "/admin/users/{id}/anonymize.json" do
    put "Anonymize a user" do
      tags "Users", "Admin"
      operationId "anonymizeUser"
      consumes "application/json"
      expected_request_schema = nil

      parameter name: :id, in: :path, type: :integer, required: true

      produces "application/json"
      response "200", "response" do
        let(:id) { Fabricate(:user).id }

        expected_response_schema = load_spec_schema("user_anonymize_response")
        schema(expected_response_schema)

        it_behaves_like "a JSON endpoint", 200 do
          let(:expected_response_schema) { expected_response_schema }
          let(:expected_request_schema) { expected_request_schema }
        end
      end
    end
  end

  path "/admin/users/{id}/log_out.json" do
    post "Log a user out" do
      tags "Users", "Admin"
      operationId "logOutUser"
      consumes "application/json"
      expected_request_schema = nil

      parameter name: :id, in: :path, type: :integer, required: true

      produces "application/json"
      response "200", "response" do
        let(:id) { Fabricate(:user).id }

        expected_response_schema = load_spec_schema("success_ok_response")
        schema(expected_response_schema)

        it_behaves_like "a JSON endpoint", 200 do
          let(:expected_response_schema) { expected_response_schema }
          let(:expected_request_schema) { expected_request_schema }
        end
      end
    end
  end

  path "/user_avatar/{username}/refresh_gravatar.json" do
    before do
      stub_request(
        :get,
        %r{https://www.gravatar.com/avatar/\w+.png\?d=404&reset_cache=\S+&s=#{Discourse.avatar_sizes.max}},
      ).with(
        headers: {
          "Accept" => "*/*",
          "Accept-Encoding" => "gzip",
          "Host" => "www.gravatar.com",
        },
      ).to_return(status: 200, body: "", headers: {})
    end

    post "Refresh gravatar" do
      tags "Users", "Admin"
      operationId "refreshGravatar"
      consumes "application/json"
      expected_request_schema = nil

      parameter name: :username, in: :path, type: :string, required: true

      produces "application/json"
      response "200", "response" do
        let(:user) { Fabricate(:user) }
        let(:username) { user.username }

        expected_response_schema = load_spec_schema("user_refresh_gravatar_response")
        schema(expected_response_schema)

        it_behaves_like "a JSON endpoint", 200 do
          let(:expected_response_schema) { expected_response_schema }
          let(:expected_request_schema) { expected_request_schema }
        end
      end
    end
  end

  path "/admin/users/list/{flag}.json" do
    get "Get a list of users" do
      tags "Users", "Admin"
      operationId "adminListUsers"
      consumes "application/json"
      expected_request_schema = nil

      parameter name: :flag,
                in: :path,
                schema: {
                  type: :string,
                  enum: %w[active new staff suspended blocked suspect],
                },
                required: true
      parameter name: :order,
                in: :query,
                schema: {
                  type: :string,
                  enum: %w[
                    created
                    last_emailed
                    seen
                    username
                    email
                    trust_level
                    days_visited
                    posts_read
                    topics_viewed
                    posts
                    read_time
                  ],
                }
      parameter name: :asc, in: :query, schema: { type: :string, enum: ["true"] }
      parameter name: :page, in: :query, type: :integer
      parameter name: :show_emails,
                in: :query,
                type: :boolean,
                description:
                  "Include user email addresses in response. These requests will be logged in the staff action logs."
      parameter name: :stats,
                in: :query,
                type: :boolean,
                description: "Include user stats information"
      parameter name: :email,
                in: :query,
                type: :string,
                description: "Filter to the user with this email address"
      parameter name: :ip,
                in: :query,
                type: :string,
                description: "Filter to users with this IP address"

      produces "application/json"
      response "200", "response" do
        let(:flag) { "active" }
        let(:order) { "created" }
        let(:asc) { "true" }
        let(:page) { 0 }
        let(:show_emails) { false }
        let(:stats) { nil }
        let(:email) { nil }
        let(:ip) { nil }

        expected_response_schema = load_spec_schema("admin_user_list_response")
        schema(expected_response_schema)

        it_behaves_like "a JSON endpoint", 200 do
          let(:expected_response_schema) { expected_response_schema }
          let(:expected_request_schema) { expected_request_schema }
        end
      end
    end
  end

  path "/user_actions.json" do
    get "Get a list of user actions" do
      tags "Users"
      operationId "listUserActions"
      consumes "application/json"
      expected_request_schema = nil

      parameter name: :offset, in: :query, type: :integer, required: true
      parameter name: :username, in: :query, type: :string, required: true
      parameter name: :filter, in: :query, type: :string, required: true

      produces "application/json"
      response "200", "response" do
        let(:offset) { 0 }
        let(:username) { Fabricate(:user).username }
        let(:filter) { "4,5" }

        expected_response_schema = load_spec_schema("user_actions_response")
        schema(expected_response_schema)

        it_behaves_like "a JSON endpoint", 200 do
          let(:expected_response_schema) { expected_response_schema }
          let(:expected_request_schema) { expected_request_schema }
        end
      end
    end
  end

  path "/session/forgot_password.json" do
    SiteSetting.hide_email_address_taken = false

    post "Send password reset email" do
      tags "Users"
      operationId "sendPasswordResetEmail"
      consumes "application/json"
      expected_request_schema = load_spec_schema("user_password_reset_request")
      parameter name: :params, in: :body, schema: expected_request_schema

      produces "application/json"
      response "200", "success response" do
        expected_response_schema = load_spec_schema("user_password_reset_response")
        schema expected_response_schema

        let(:user) { Fabricate(:user) }
        let(:params) { { "login" => user.username } }

        it_behaves_like "a JSON endpoint", 200 do
          let(:expected_response_schema) { expected_response_schema }
          let(:expected_request_schema) { expected_request_schema }
        end
      end
    end
  end

  path "/users/password-reset/{token}.json" do
    put "Change password" do
      tags "Users"
      operationId "changePassword"
      consumes "application/json"
      expected_request_schema = load_spec_schema("user_password_change_request")
      parameter name: :token, in: :path, type: :string, required: true
      parameter name: :params, in: :body, schema: expected_request_schema

      produces "application/json"
      response "200", "success response" do
        expected_response_schema = nil

        let(:user) { Fabricate(:user) }
        let(:token) do
          Fabricate(:email_token, user: user, scope: EmailToken.scopes[:password_reset]).token
        end
        let(:params) { { "username" => user.username, "password" => "NH8QYbxYS5Zv5qEFzA4jULvM" } }

        it_behaves_like "a JSON endpoint", 200 do
          let(:expected_response_schema) { expected_response_schema }
          let(:expected_request_schema) { expected_request_schema }
        end
      end
    end
  end

  path "/u/{username}/emails.json" do
    get "Get email addresses belonging to a user" do
      tags "Users"
      operationId "getUserEmails"
      consumes "application/json"
      expected_request_schema = nil
      parameter name: :username, in: :path, type: :string, required: true

      produces "application/json"
      response "200", "success response" do
        expected_response_schema = load_spec_schema("user_emails_response")
        schema expected_response_schema

        let(:username) { Fabricate(:user).username }

        it_behaves_like "a JSON endpoint", 200 do
          let(:expected_response_schema) { expected_response_schema }
          let(:expected_request_schema) { expected_request_schema }
        end
      end
    end
  end
end
