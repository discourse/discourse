# frozen_string_literal: true
require "swagger_helper"

RSpec.describe "tags" do
  let(:admin) { Fabricate(:admin) }
  let!(:tag) { Fabricate(:tag, name: "foo") }
  let!(:tag_group) { Fabricate(:tag_group, tags: [tag]) }

  before do
    SiteSetting.tagging_enabled = true
    Jobs.run_immediately!
    sign_in(admin)
  end

  path "/tag_groups.json" do
    get "Get a list of tag groups" do
      tags "Tags"
      operationId "listTagGroups"

      produces "application/json"
      response "200", "tags" do
        schema type: :object,
               properties: {
                 tag_groups: {
                   type: :array,
                   items: {
                     type: :object,
                     properties: {
                       id: {
                         type: :integer,
                       },
                       name: {
                         type: :string,
                       },
                       tag_names: {
                         type: :array,
                         items: {
                         },
                       },
                       parent_tag_name: {
                         type: :array,
                         items: {
                         },
                       },
                       one_per_topic: {
                         type: :boolean,
                       },
                       permissions: {
                         type: :object,
                         properties: {
                           staff: {
                             type: :integer,
                           },
                         },
                       },
                     },
                   },
                 },
               }

        run_test!
      end
    end
  end

  path "/tag_groups.json" do
    post "Creates a tag group" do
      tags "Tags"
      operationId "createTagGroup"
      consumes "application/json"
      expected_request_schema = load_spec_schema("tag_group_create_request")

      parameter name: :params, in: :body, schema: expected_request_schema

      produces "application/json"
      response "200", "tag group created" do
        expected_response_schema = load_spec_schema("tag_group_create_response")

        let(:params) { { "name" => "todo" } }

        schema(expected_response_schema)

        it_behaves_like "a JSON endpoint", 200 do
          let(:expected_response_schema) { expected_response_schema }
          let(:expected_request_schema) { expected_request_schema }
        end
      end
    end
  end

  path "/tag_groups/{id}.json" do
    get "Get a single tag group" do
      tags "Tags"
      operationId "getTagGroup"
      consumes "application/json"
      parameter name: :id, in: :path, schema: { type: :string }

      produces "application/json"
      response "200", "notifications" do
        schema type: :object,
               properties: {
                 tag_group: {
                   type: :object,
                   properties: {
                     id: {
                       type: :integer,
                     },
                     name: {
                       type: :string,
                     },
                     tag_names: {
                       type: :array,
                       items: {
                       },
                     },
                     parent_tag_name: {
                       type: :array,
                       items: {
                       },
                     },
                     one_per_topic: {
                       type: :boolean,
                     },
                     permissions: {
                       type: :object,
                       properties: {
                         everyone: {
                           type: :integer,
                         },
                       },
                     },
                   },
                 },
               }

        let(:id) { tag_group.id }
        run_test!
      end
    end
  end

  path "/tag_groups/{id}.json" do
    put "Update tag group" do
      tags "Tags"
      operationId "updateTagGroup"
      consumes "application/json"
      parameter name: :id, in: :path, schema: { type: :string }
      parameter name: :put_body,
                in: :body,
                schema: {
                  type: :object,
                  properties: {
                    name: {
                      type: :string,
                    },
                  },
                }

      produces "application/json"
      response "200", "Tag group updated" do
        schema type: :object,
               properties: {
                 success: {
                   type: :string,
                 },
                 tag_group: {
                   type: :object,
                   properties: {
                     id: {
                       type: :integer,
                     },
                     name: {
                       type: :string,
                     },
                     tag_names: {
                       type: :array,
                       items: {
                       },
                     },
                     parent_tag_name: {
                       type: :array,
                       items: {
                       },
                     },
                     one_per_topic: {
                       type: :boolean,
                     },
                     permissions: {
                       type: :object,
                       properties: {
                         everyone: {
                           type: :integer,
                         },
                       },
                     },
                   },
                 },
               }

        let(:id) { tag_group.id }
        let(:put_body) { { name: "todo2" } }
        run_test!
      end
    end
  end

  path "/tags.json" do
    get "Get a list of tags" do
      tags "Tags"
      operationId "listTags"

      produces "application/json"
      response "200", "notifications" do
        schema type: :object,
               properties: {
                 tags: {
                   type: :array,
                   items: {
                     type: :object,
                     properties: {
                       id: {
                         type: :string,
                       },
                       text: {
                         type: :string,
                       },
                       count: {
                         type: :integer,
                       },
                       pm_count: {
                         type: :integer,
                       },
                       target_tag: {
                         type: %i[string null],
                       },
                     },
                   },
                 },
                 extras: {
                   type: :object,
                   properties: {
                     categories: {
                       type: :array,
                       items: {
                       },
                     },
                   },
                 },
               }

        run_test!
      end
    end
  end

  path "/tag/{name}.json" do
    get "Get a specific tag" do
      tags "Tags"
      operationId "getTag"
      parameter name: :name, in: :path, schema: { type: :string }

      produces "application/json"
      response "200", "notifications" do
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
                     tags: {
                       type: :array,
                       items: {
                         type: :object,
                         properties: {
                           id: {
                             type: :integer,
                           },
                           name: {
                             type: :string,
                           },
                           topic_count: {
                             type: :integer,
                           },
                           staff: {
                             type: :boolean,
                           },
                         },
                       },
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
                           tags: {
                             type: :array,
                             items: {
                             },
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
                                   type: %i[string null],
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
        let(:name) { tag.name }
        run_test!
      end
    end
  end
end
