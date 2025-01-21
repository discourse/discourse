# frozen_string_literal: true
require "swagger_helper"

RSpec.describe "topics" do
  let(:"Api-Key") { Fabricate(:api_key).key }
  let(:"Api-Username") { "system" }

  path "/t/{id}/posts.json" do
    get "Get specific posts from a topic" do
      tags "Topics"
      operationId "getSpecificPostsFromTopic"
      consumes "application/json"
      parameter name: "Api-Key", in: :header, type: :string, required: true
      parameter name: "Api-Username", in: :header, type: :string, required: true
      parameter name: :id, in: :path, schema: { type: :string }

      parameter name: :post_body,
                in: :body,
                schema: {
                  type: :object,
                  properties: {
                    "post_ids[]": {
                      type: :integer,
                    },
                  },
                  required: ["post_ids[]"],
                }

      produces "application/json"
      response "200", "specific posts" do
        schema type: :object,
               properties: {
                 post_stream: {
                   type: :object,
                   properties: {
                     posts: {
                       type: :array,
                       items: {
                         type: :object,
                         properties: {
                           id: {
                             type: :integer,
                           },
                           name: {
                             type: %i[string null],
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
                             type: %i[string null],
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
                           read: {
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
                                 can_act: {
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
                           reviewable_id: {
                             type: :integer,
                           },
                           reviewable_score_count: {
                             type: :integer,
                           },
                           reviewable_score_pending_count: {
                             type: :integer,
                           },
                         },
                       },
                     },
                   },
                 },
                 id: {
                   type: :integer,
                 },
               }

        let(:post_body) { { "post_ids[]": 1 } }
        let(:id) { Fabricate(:topic).id }

        run_test!
      end
    end
  end

  path "/t/{id}.json" do
    get "Get a single topic" do
      tags "Topics"
      operationId "getTopic"
      consumes "application/json"
      parameter name: "Api-Key", in: :header, type: :string, required: true
      parameter name: "Api-Username", in: :header, type: :string, required: true
      parameter name: :id, in: :path, schema: { type: :string }
      expected_request_schema = nil

      produces "application/json"
      response "200", "specific posts" do
        let(:id) { Fabricate(:topic).id }

        expected_response_schema = load_spec_schema("topic_show_response")
        schema expected_response_schema

        it_behaves_like "a JSON endpoint", 200 do
          let(:expected_response_schema) { expected_response_schema }
          let(:expected_request_schema) { expected_request_schema }
        end
      end
    end

    delete "Remove a topic" do
      tags "Topics"
      operationId "removeTopic"
      consumes "application/json"
      parameter name: "Api-Key", in: :header, type: :string, required: true
      parameter name: "Api-Username", in: :header, type: :string, required: true
      parameter name: :id, in: :path, schema: { type: :string }
      response "200", "specific posts" do
        let!(:post) { Fabricate(:post) }
        let(:id) { post.topic.id }

        run_test!
      end
    end
  end

  path "/t/-/{id}.json" do
    put "Update a topic" do
      tags "Topics"
      operationId "updateTopic"
      consumes "application/json"
      parameter name: "Api-Key", in: :header, type: :string, required: true
      parameter name: "Api-Username", in: :header, type: :string, required: true
      parameter name: :id, in: :path, schema: { type: :string }

      parameter name: :post_body,
                in: :body,
                schema: {
                  type: :object,
                  properties: {
                    topic: {
                      type: :object,
                      properties: {
                        title: {
                          type: :string,
                        },
                        category_id: {
                          type: :integer,
                        },
                      },
                    },
                  },
                }

      produces "application/json"
      response "200", "topic updated" do
        schema type: :object,
               properties: {
                 basic_topic: {
                   type: :object,
                   properties: {
                     id: {
                       type: :integer,
                     },
                     title: {
                       type: :string,
                     },
                     fancy_title: {
                       type: :string,
                     },
                     slug: {
                       type: :string,
                     },
                     posts_count: {
                       type: :integer,
                     },
                   },
                 },
               }

        let(:post_body) { { title: "New topic title" } }
        let!(:post) { Fabricate(:post) }
        let(:id) { post.topic.id }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data["basic_topic"]["title"]).to eq("New topic title")
        end
      end
    end
  end

  path "/t/{id}/invite.json" do
    post "Invite to topic" do
      tags "Topics", "Invites"
      operationId "inviteToTopic"
      consumes "application/json"
      parameter name: "Api-Key", in: :header, type: :string, required: true
      parameter name: "Api-Username", in: :header, type: :string, required: true
      parameter name: :id, in: :path, schema: { type: :string }

      parameter name: :request_body,
                in: :body,
                schema: {
                  type: :object,
                  properties: {
                    user: {
                      type: :string,
                    },
                    email: {
                      type: :string,
                    },
                  },
                }

      produces "application/json"
      response "200", "topic updated" do
        schema type: :object,
               properties: {
                 user: {
                   type: :object,
                   properties: {
                     id: {
                       type: :integer,
                     },
                     username: {
                       type: :string,
                     },
                     name: {
                       type: :string,
                     },
                     avatar_template: {
                       type: :string,
                     },
                   },
                 },
               }

        let(:username) { Fabricate(:user).username }
        let(:request_body) { { user: username } }
        let(:id) { Fabricate(:private_message_topic).id }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data["user"]["username"]).to eq(username)
        end
      end
    end
  end

  path "/t/{id}/invite-group.json" do
    post "Invite group to topic" do
      tags "Topics", "Invites"
      operationId "inviteGroupToTopic"
      consumes "application/json"
      parameter name: "Api-Key", in: :header, type: :string, required: true
      parameter name: "Api-Username", in: :header, type: :string, required: true
      parameter name: :id, in: :path, schema: { type: :string }

      parameter name: :request_body,
                in: :body,
                schema: {
                  type: :object,
                  properties: {
                    group: {
                      type: :string,
                      description: "The name of the group to invite",
                    },
                    should_notify: {
                      type: :boolean,
                      description: "Whether to notify the group, it defaults to true",
                    },
                  },
                }

      produces "application/json"
      response "200", "invites to a PM" do
        schema type: :object,
               properties: {
                 group: {
                   type: :object,
                   properties: {
                     id: {
                       type: :integer,
                     },
                     name: {
                       type: :string,
                     },
                   },
                 },
               }

        let!(:admins) { Group[:admins] }
        let(:request_body) { { group: admins.name } }
        let(:pm) { Fabricate(:private_message_topic) }
        let(:id) { pm.id }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data["group"]["name"]).to eq(admins.name)
          expect(pm.allowed_groups.first.id).to eq(admins.id)
        end
      end
    end
  end

  path "/t/{id}/bookmark.json" do
    put "Bookmark topic" do
      tags "Topics"
      operationId "bookmarkTopic"
      consumes "application/json"
      parameter name: "Api-Key", in: :header, type: :string, required: true
      parameter name: "Api-Username", in: :header, type: :string, required: true
      parameter name: :id, in: :path, schema: { type: :string }

      produces "application/json"
      response "200", "topic updated" do
        let!(:post) { Fabricate(:post) }
        let(:id) { post.topic.id }

        run_test!
      end
    end
  end

  path "/t/{id}/status.json" do
    put "Update the status of a topic" do
      tags "Topics"
      operationId "updateTopicStatus"
      consumes "application/json"
      parameter name: "Api-Key", in: :header, type: :string, required: true
      parameter name: "Api-Username", in: :header, type: :string, required: true
      parameter name: :id, in: :path, schema: { type: :string }

      parameter name: :request_body,
                in: :body,
                schema: {
                  type: :object,
                  properties: {
                    status: {
                      type: :string,
                      enum: %w[closed pinned pinned_globally archived visible],
                    },
                    enabled: {
                      type: :string,
                      enum: %w[true false],
                    },
                    until: {
                      type: :string,
                      description: "Only required for `pinned` and `pinned_globally`",
                      example: "2030-12-31",
                    },
                  },
                  required: %w[status enabled],
                }

      produces "application/json"
      response "200", "topic updated" do
        schema type: :object,
               properties: {
                 success: {
                   type: :string,
                   example: "OK",
                 },
                 topic_status_update: {
                   type: %i[string null],
                 },
               }

        let(:request_body) { { status: "closed", enabled: "true" } }
        let(:id) { Fabricate(:topic).id }

        run_test!
      end
    end
  end

  path "/latest.json" do
    get "Get the latest topics" do
      tags "Topics"
      operationId "listLatestTopics"
      consumes "application/json"
      parameter name: "Api-Key", in: :header, type: :string, required: true
      parameter name: "Api-Username", in: :header, type: :string, required: true
      parameter(
        name: :order,
        in: :query,
        type: :string,
        description:
          "Enum: `default`, `created`, `activity`, `views`, `posts`, `category`, `likes`, `op_likes`, `posters`",
      )
      parameter(
        name: :ascending,
        in: :query,
        type: :string,
        description: "Defaults to `desc`, add `ascending=true` to sort asc",
      )
      parameter(
        name: :per_page,
        in: :query,
        type: :integer,
        description: "Maximum number of topics returned, between 1-100",
      )

      produces "application/json"
      response "200", "topic updated" do
        schema type: :object,
               properties: {
                 users: {
                   type: :array,
                   items: {
                     type: :object,
                     properties: {
                       id: {
                         type: :integer,
                       },
                       username: {
                         type: :string,
                       },
                       name: {
                         type: %i[string null],
                       },
                       avatar_template: {
                         type: :string,
                       },
                     },
                   },
                 },
                 primary_groups: {
                   type: :array,
                   items: {
                   },
                 },
                 topic_list: {
                   type: :object,
                   properties: {
                     can_create_topic: {
                       type: :boolean,
                     },
                     draft: {
                       type: %i[string null],
                     },
                     draft_key: {
                       type: :string,
                     },
                     draft_sequence: {
                       type: :integer,
                     },
                     per_page: {
                       type: :integer,
                     },
                     topics: {
                       type: :array,
                       items: {
                         type: :object,
                         properties: {
                           id: {
                             type: :integer,
                           },
                           title: {
                             type: :string,
                           },
                           fancy_title: {
                             type: :string,
                           },
                           slug: {
                             type: :string,
                           },
                           posts_count: {
                             type: :integer,
                           },
                           reply_count: {
                             type: :integer,
                           },
                           highest_post_number: {
                             type: :integer,
                           },
                           image_url: {
                             type: :string,
                           },
                           created_at: {
                             type: :string,
                           },
                           last_posted_at: {
                             type: :string,
                           },
                           bumped: {
                             type: :boolean,
                           },
                           bumped_at: {
                             type: :string,
                           },
                           archetype: {
                             type: :string,
                           },
                           unseen: {
                             type: :boolean,
                           },
                           last_read_post_number: {
                             type: :integer,
                           },
                           unread_posts: {
                             type: :integer,
                           },
                           pinned: {
                             type: :boolean,
                           },
                           unpinned: {
                             type: %i[string null],
                           },
                           visible: {
                             type: :boolean,
                           },
                           closed: {
                             type: :boolean,
                           },
                           archived: {
                             type: :boolean,
                           },
                           notification_level: {
                             type: :integer,
                           },
                           bookmarked: {
                             type: :boolean,
                           },
                           liked: {
                             type: :boolean,
                           },
                           views: {
                             type: :integer,
                           },
                           like_count: {
                             type: :integer,
                           },
                           has_summary: {
                             type: :boolean,
                           },
                           last_poster_username: {
                             type: :string,
                           },
                           category_id: {
                             type: :integer,
                           },
                           op_like_count: {
                             type: :integer,
                           },
                           pinned_globally: {
                             type: :boolean,
                           },
                           featured_link: {
                             type: %i[string null],
                           },
                           posters: {
                             type: :array,
                             items: {
                               type: :object,
                               properties: {
                                 extras: {
                                   type: :string,
                                 },
                                 description: {
                                   type: :string,
                                 },
                                 user_id: {
                                   type: :integer,
                                 },
                                 primary_group_id: {
                                   type: %i[integer null],
                                 },
                               },
                             },
                           },
                         },
                       },
                     },
                   },
                 },
               }

        let(:order) { "default" }
        let(:ascending) { "false" }
        let(:per_page) { 20 }

        run_test!
      end
    end
  end

  path "/top.json" do
    get "Get the top topics filtered by period" do
      tags "Topics"
      operationId "listTopTopics"
      consumes "application/json"
      parameter name: "Api-Key", in: :header, type: :string, required: true
      parameter name: "Api-Username", in: :header, type: :string, required: true
      parameter(
        name: :period,
        in: :query,
        type: :string,
        description: "Enum: `all`, `yearly`, `quarterly`, `monthly`, `weekly`, `daily`",
      )
      parameter(
        name: :per_page,
        in: :query,
        type: :integer,
        description: "Maximum number of topics returned, between 1-100",
      )

      produces "application/json"
      response "200", "response" do
        schema type: :object,
               properties: {
                 users: {
                   type: :array,
                   items: {
                     type: :object,
                     properties: {
                       id: {
                         type: :integer,
                       },
                       username: {
                         type: :string,
                       },
                       name: {
                         type: :string,
                       },
                       avatar_template: {
                         type: :string,
                       },
                     },
                   },
                 },
                 primary_groups: {
                   type: :array,
                   items: {
                   },
                 },
                 topic_list: {
                   type: :object,
                   properties: {
                     can_create_topic: {
                       type: :boolean,
                     },
                     draft: {
                       type: %i[string null],
                     },
                     draft_key: {
                       type: :string,
                     },
                     draft_sequence: {
                       type: :integer,
                     },
                     for_period: {
                       type: :string,
                     },
                     per_page: {
                       type: :integer,
                     },
                     topics: {
                       type: :array,
                       items: {
                         type: :object,
                         properties: {
                           id: {
                             type: :integer,
                           },
                           title: {
                             type: :string,
                           },
                           fancy_title: {
                             type: :string,
                           },
                           slug: {
                             type: :string,
                           },
                           posts_count: {
                             type: :integer,
                           },
                           reply_count: {
                             type: :integer,
                           },
                           highest_post_number: {
                             type: :integer,
                           },
                           image_url: {
                             type: %i[string null],
                           },
                           created_at: {
                             type: :string,
                           },
                           last_posted_at: {
                             type: :string,
                           },
                           bumped: {
                             type: :boolean,
                           },
                           bumped_at: {
                             type: :string,
                           },
                           archetype: {
                             type: :string,
                           },
                           unseen: {
                             type: :boolean,
                           },
                           last_read_post_number: {
                             type: :integer,
                           },
                           unread_posts: {
                             type: :integer,
                           },
                           pinned: {
                             type: :boolean,
                           },
                           unpinned: {
                             type: :boolean,
                           },
                           visible: {
                             type: :boolean,
                           },
                           closed: {
                             type: :boolean,
                           },
                           archived: {
                             type: :boolean,
                           },
                           notification_level: {
                             type: :integer,
                           },
                           bookmarked: {
                             type: :boolean,
                           },
                           liked: {
                             type: :boolean,
                           },
                           views: {
                             type: :integer,
                           },
                           like_count: {
                             type: :integer,
                           },
                           has_summary: {
                             type: :boolean,
                           },
                           last_poster_username: {
                             type: :string,
                           },
                           category_id: {
                             type: :integer,
                           },
                           op_like_count: {
                             type: :integer,
                           },
                           pinned_globally: {
                             type: :boolean,
                           },
                           featured_link: {
                             type: %i[string null],
                           },
                           posters: {
                             type: :array,
                             items: {
                               type: :object,
                               properties: {
                                 extras: {
                                   type: %i[string null],
                                 },
                                 description: {
                                   type: :string,
                                 },
                                 user_id: {
                                   type: :integer,
                                 },
                                 primary_group_id: {
                                   type: %i[integer null],
                                 },
                               },
                             },
                           },
                         },
                       },
                     },
                   },
                 },
               }

        let(:period) { "all" }
        let(:per_page) { 20 }

        run_test!
      end
    end
  end

  path "/t/{id}/notifications.json" do
    post "Set notification level" do
      tags "Topics"
      operationId "setNotificationLevel"
      consumes "application/json"
      parameter name: "Api-Key", in: :header, type: :string, required: true
      parameter name: "Api-Username", in: :header, type: :string, required: true
      parameter name: :id, in: :path, schema: { type: :string }

      parameter name: :request_body,
                in: :body,
                schema: {
                  type: :object,
                  properties: {
                    notification_level: {
                      type: :string,
                      enum: %w[0 1 2 3],
                    },
                  },
                  required: ["notification_level"],
                }

      produces "application/json"
      response "200", "topic updated" do
        schema type: :object, properties: { success: { type: :string, example: "OK" } }

        let(:request_body) { { notification_level: "3" } }
        let(:id) { Fabricate(:topic).id }

        run_test!
      end
    end
  end

  path "/t/{id}/change-timestamp.json" do
    put "Update topic timestamp" do
      tags "Topics"
      operationId "updateTopicTimestamp"
      consumes "application/json"
      parameter name: "Api-Key", in: :header, type: :string, required: true
      parameter name: "Api-Username", in: :header, type: :string, required: true
      parameter name: :id, in: :path, schema: { type: :string }

      parameter name: :request_body,
                in: :body,
                schema: {
                  type: :object,
                  properties: {
                    timestamp: {
                      type: :string,
                      example: "1594291380",
                    },
                  },
                  required: ["timestamp"],
                }

      produces "application/json"
      response "200", "topic updated" do
        schema type: :object, properties: { success: { type: :string, example: "OK" } }

        let(:request_body) { { timestamp: "1594291380" } }
        let!(:post) { Fabricate(:post) }
        let(:id) { post.topic.id }

        run_test!
      end
    end
  end

  path "/t/{id}/timer.json" do
    post "Create topic timer" do
      tags "Topics"
      operationId "createTopicTimer"
      consumes "application/json"
      parameter name: "Api-Key", in: :header, type: :string, required: true
      parameter name: "Api-Username", in: :header, type: :string, required: true
      parameter name: :id, in: :path, schema: { type: :string }

      parameter name: :request_body,
                in: :body,
                schema: {
                  type: :object,
                  properties: {
                    time: {
                      type: :string,
                      example: "",
                    },
                    status_type: {
                      type: :string,
                    },
                    based_on_last_post: {
                      type: :boolean,
                    },
                    category_id: {
                      type: :integer,
                    },
                  },
                }

      produces "application/json"
      response "200", "topic updated" do
        schema type: :object,
               properties: {
                 success: {
                   type: :string,
                   example: "OK",
                 },
                 execute_at: {
                   type: :string,
                 },
                 duration: {
                   type: %i[string null],
                 },
                 based_on_last_post: {
                   type: :boolean,
                 },
                 closed: {
                   type: :boolean,
                 },
                 category_id: {
                   type: %i[integer null],
                 },
               }

        let(:request_body) { { time: Time.current + 1.day, status_type: "close" } }
        let!(:topic_post) { Fabricate(:post) }
        let(:id) { topic_post.topic.id }

        run_test!
      end
    end
  end

  path "/t/external_id/{external_id}.json" do
    get "Get topic by external_id" do
      tags "Topics"
      operationId "getTopicByExternalId"
      consumes "application/json"
      parameter name: :external_id, in: :path, type: :string, required: true
      expected_request_schema = nil

      produces "application/json"
      response "301", "redirects to /t/{topic_id}.json" do
        expected_response_schema = nil
        schema expected_response_schema

        let(:topic) { Fabricate(:topic, external_id: "external_id_1") }
        let(:external_id) { topic.external_id }

        run_test! { |response| expect(response).to redirect_to(topic.relative_url + ".json") }
      end
    end
  end
end
