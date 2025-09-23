# frozen_string_literal: true
require "swagger_helper"

RSpec.describe "posts" do
  let(:"Api-Key") { Fabricate(:api_key).key }
  let(:"Api-Username") { "system" }
  let(:admin) { Fabricate(:admin) }

  before do
    Jobs.run_immediately!
    sign_in(admin)
  end

  path "/posts.json" do
    get "List latest posts across topics" do
      tags "Posts"
      operationId "listPosts"
      consumes "application/json"
      expected_request_schema = nil
      parameter name: :before,
                in: :query,
                type: :integer,
                required: false,
                description: "Load posts with an id lower than this value. Useful for pagination."

      produces "application/json"
      response "200", "latest posts" do
        expected_response_schema = load_spec_schema("latest_posts_response")
        schema expected_response_schema

        let!(:post) { Fabricate(:post) }

        it_behaves_like "a JSON endpoint", 200 do
          let(:expected_response_schema) { expected_response_schema }
          let(:expected_request_schema) { expected_request_schema }
        end
      end
    end

    post "Creates a new topic, a new post, or a private message" do
      tags "Posts", "Topics", "Private Messages"
      operationId "createTopicPostPM"
      consumes "application/json"
      expected_request_schema = load_spec_schema("topic_create_request")
      parameter name: :params, in: :body, schema: expected_request_schema

      produces "application/json"
      response "200", "post created" do
        expected_response_schema = load_spec_schema("topic_create_response")
        schema expected_response_schema

        let(:params) do
          post = Fabricate(:post)
          post.serializable_hash(only: %i[topic_id raw created_at]).as_json
        end

        it_behaves_like "a JSON endpoint", 200 do
          let(:expected_response_schema) { expected_response_schema }
          let(:expected_request_schema) { expected_request_schema }
        end
      end
    end
  end

  path "/posts/{id}.json" do
    get "Retrieve a single post" do
      tags "Posts"
      operationId "getPost"
      consumes "application/json"
      description <<~TEXT
      This endpoint can be used to get the number of likes on a post using the
      `actions_summary` property in the response. `actions_summary` responses
      with the id of `2` signify a `like`. If there are no `actions_summary`
      items with the id of `2`, that means there are 0 likes. Other ids likely
      refer to various different flag types.
      TEXT

      expected_request_schema = nil
      parameter name: :id, in: :path, schema: { type: :string }

      produces "application/json"

      response "200", "single post" do
        expected_response_schema = load_spec_schema("post_show_response")
        schema expected_response_schema

        let(:id) { Fabricate(:post).id }
        run_test!

        it_behaves_like "a JSON endpoint", 200 do
          let(:expected_response_schema) { expected_response_schema }
          let(:expected_request_schema) { expected_request_schema }
        end
      end

      response "200", "single reviewable post" do
        expected_response_schema = load_spec_schema("post_show_response")
        schema expected_response_schema

        let(:id) do
          topic = Fabricate(:topic)
          post = Fabricate(:post, topic: topic)
          Fabricate(:reviewable_flagged_post, topic: topic, target: post)

          post.id
        end

        let(:moderator) { Fabricate(:moderator) }
        before { sign_in(moderator) }

        run_test!

        it_behaves_like "a JSON endpoint", 200 do
          let(:expected_response_schema) { expected_response_schema }
          let(:expected_request_schema) { expected_request_schema }
        end
      end
    end

    put "Update a single post" do
      tags "Posts"
      operationId "updatePost"
      consumes "application/json"
      expected_request_schema = load_spec_schema("post_update_request")
      parameter name: :id, in: :path, schema: { type: :string }
      parameter name: :params, in: :body, schema: expected_request_schema

      produces "application/json"
      response "200", "post updated" do
        expected_response_schema = load_spec_schema("post_update_response")
        schema expected_response_schema

        let(:params) do
          { "post" => { "raw" => "Updated content!", "edit_reason" => "fixed typo" } }
        end
        let(:id) { Fabricate(:post).id }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data["post"]["cooked"]).to eq("<p>Updated content!</p>")
          expect(data["post"]["edit_reason"]).to eq("fixed typo")
        end

        it_behaves_like "a JSON endpoint", 200 do
          let(:expected_response_schema) { expected_response_schema }
          let(:expected_request_schema) { expected_request_schema }
        end
      end
    end

    delete "delete a single post" do
      tags "Posts"
      operationId "deletePost"
      consumes "application/json"
      expected_request_schema = load_spec_schema("post_delete_request")
      parameter name: :id, in: :path, schema: { type: :integer }
      parameter name: :params, in: :body, schema: expected_request_schema

      produces "application/json"
      response "200", "success response" do
        expected_response_schema = nil
        schema expected_response_schema

        let(:topic) { Fabricate(:topic) }
        let(:post) { Fabricate(:post, topic_id: topic.id, post_number: 3) }
        let(:id) { post.id }
        let(:params) { { "force_destroy" => false } }

        it_behaves_like "a JSON endpoint", 200 do
          let(:expected_response_schema) { expected_response_schema }
          let(:expected_request_schema) { expected_request_schema }
        end
      end
    end
  end

  path "/posts/{id}/replies.json" do
    get "List replies to a post" do
      tags "Posts"
      operationId "postReplies"
      consumes "application/json"
      expected_request_schema = nil
      parameter name: :id, in: :path, schema: { type: :string }

      produces "application/json"
      response "200", "post replies" do
        expected_response_schema = load_spec_schema("post_replies_response")
        schema expected_response_schema

        fab!(:user)
        fab!(:topic)
        fab!(:post) { Fabricate(:post, topic: topic, user: user) }
        let!(:reply) do
          PostCreator.new(
            user,
            raw: "this is some text for my post",
            topic_id: topic.id,
            reply_to_post_number: post.post_number,
          ).create
        end
        let!(:id) { post.id }

        it_behaves_like "a JSON endpoint", 200 do
          let(:expected_response_schema) { expected_response_schema }
          let(:expected_request_schema) { expected_request_schema }
        end
      end
    end
  end

  path "/posts/{id}/locked.json" do
    put "Lock a post from being edited" do
      tags "Posts"
      operationId "lockPost"
      consumes "application/json"
      parameter name: "Api-Key", in: :header, type: :string, required: true
      parameter name: "Api-Username", in: :header, type: :string, required: true
      parameter name: :id, in: :path, schema: { type: :string }

      parameter name: :post_body,
                in: :body,
                schema: {
                  type: :object,
                  properties: {
                    locked: {
                      type: :string,
                    },
                  },
                  required: ["locked"],
                }

      produces "application/json"
      response "200", "post updated" do
        schema type: :object, properties: { locked: { type: :boolean } }

        let(:post_body) { { locked: "true" } }
        let(:id) { Fabricate(:post).id }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data["locked"]).to eq(true)
        end
      end
    end
  end

  path "/post_actions.json" do
    post "Like a post and other actions" do
      tags "Posts"
      operationId "performPostAction"
      consumes "application/json"
      parameter name: "Api-Key", in: :header, type: :string, required: true
      parameter name: "Api-Username", in: :header, type: :string, required: true

      parameter name: :post_body,
                in: :body,
                schema: {
                  type: :object,
                  properties: {
                    id: {
                      type: :integer,
                    },
                    post_action_type_id: {
                      type: :integer,
                    },
                    flag_topic: {
                      type: :boolean,
                    },
                  },
                  required: %w[id post_action_type_id],
                }

      produces "application/json"
      response "200", "post updated" do
        schema type: :object,
               properties: {
                 id: {
                   type: :integer,
                 },
                 name: {
                   type: :string,
                 },
                 username: {
                   type: :string,
                 },
                 avatar_template: {
                   type: :string,
                 },
                 created_at: {
                   type: :string,
                 },
                 cooked: {
                   type: :string,
                 },
                 post_number: {
                   type: :integer,
                 },
                 post_type: {
                   type: :integer,
                 },
                 updated_at: {
                   type: :string,
                 },
                 reply_count: {
                   type: :integer,
                 },
                 reply_to_post_number: {
                   type: %i[string null],
                 },
                 quote_count: {
                   type: :integer,
                 },
                 incoming_link_count: {
                   type: :integer,
                 },
                 reads: {
                   type: :integer,
                 },
                 readers_count: {
                   type: :integer,
                 },
                 score: {
                   type: :number,
                 },
                 yours: {
                   type: :boolean,
                 },
                 topic_id: {
                   type: :integer,
                 },
                 topic_slug: {
                   type: :string,
                 },
                 display_username: {
                   type: :string,
                 },
                 primary_group_name: {
                   type: %i[string null],
                 },
                 flair_name: {
                   type: %i[string null],
                 },
                 flair_url: {
                   type: %i[string null],
                 },
                 flair_bg_color: {
                   type: %i[string null],
                 },
                 flair_color: {
                   type: %i[string null],
                 },
                 version: {
                   type: :integer,
                 },
                 can_edit: {
                   type: :boolean,
                 },
                 can_delete: {
                   type: :boolean,
                 },
                 can_recover: {
                   type: :boolean,
                 },
                 can_wiki: {
                   type: :boolean,
                 },
                 user_title: {
                   type: %i[string null],
                 },
                 actions_summary: {
                   type: :array,
                   items: {
                     type: :object,
                     properties: {
                       id: {
                         type: :integer,
                       },
                       count: {
                         type: :integer,
                       },
                       acted: {
                         type: :boolean,
                       },
                       can_undo: {
                         type: :boolean,
                       },
                     },
                   },
                 },
                 moderator: {
                   type: :boolean,
                 },
                 admin: {
                   type: :boolean,
                 },
                 staff: {
                   type: :boolean,
                 },
                 user_id: {
                   type: :integer,
                 },
                 hidden: {
                   type: :boolean,
                 },
                 trust_level: {
                   type: :integer,
                 },
                 deleted_at: {
                   type: %i[string null],
                 },
                 user_deleted: {
                   type: :boolean,
                 },
                 edit_reason: {
                   type: %i[string null],
                 },
                 can_view_edit_history: {
                   type: :boolean,
                 },
                 wiki: {
                   type: :boolean,
                 },
                 notice: {
                   type: :object,
                 },
                 notice_created_by_user: {
                   type: %i[object null],
                 },
                 reviewable_id: {
                   type: %i[integer null],
                 },
                 reviewable_score_count: {
                   type: :integer,
                 },
                 reviewable_score_pending_count: {
                   type: :integer,
                 },
               }

        let(:id) { Fabricate(:post).id }
        let(:post_body) { { id: id, post_action_type_id: 2 } }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data["actions_summary"][0]["id"]).to eq(2)
          expect(data["actions_summary"][0]["count"]).to eq(1)
        end
      end
    end
  end
end
