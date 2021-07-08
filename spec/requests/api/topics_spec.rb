# frozen_string_literal: true
require 'swagger_helper'

describe 'topics' do

  let(:'Api-Key') { Fabricate(:api_key).key }
  let(:'Api-Username') { 'system' }

  path '/t/{id}/posts.json' do
    get 'Get specific posts from a topic' do
      tags 'Topics'
      consumes 'application/json'
      parameter name: 'Api-Key', in: :header, type: :string, required: true
      parameter name: 'Api-Username', in: :header, type: :string, required: true
      parameter name: :id, in: :path, schema: { type: :string }

      parameter name: :post_body, in: :body, schema: {
        type: :object,
        properties: {
          'post_ids[]': { type: :integer }
        }, required: [ 'post_ids[]' ]
      }

      produces 'application/json'
      response '200', 'specific posts' do
        schema type: :object, properties: {
          post_stream: {
            type: :object,
            properties: {
              posts: {
                type: :array,
                items: {
                  type: :object,
                  properties: {
                    id: { type: :integer },
                    name: { type: :string, nullable: true },
                    username: { type: :string },
                    avatar_template: { type: :string },
                    created_at: { type: :string },
                    cooked: { type: :string },
                    post_number: { type: :integer },
                    post_type: { type: :integer },
                    updated_at: { type: :string },
                    reply_count: { type: :integer },
                    reply_to_post_number: { type: :string, nullable: true },
                    quote_count: { type: :integer },
                    incoming_link_count: { type: :integer },
                    reads: { type: :integer },
                    readers_count: { type: :integer },
                    score: { type: :integer },
                    yours: { type: :boolean },
                    topic_id: { type: :integer },
                    topic_slug: { type: :string },
                    display_username: { type: :string, nullable: true },
                    primary_group_name: { type: :string, nullable: true },
                    flair_name: { type: :string, nullable: true },
                    flair_url: { type: :string, nullable: true },
                    flair_bg_color: { type: :string, nullable: true },
                    flair_color: { type: :string, nullable: true },
                    version: { type: :integer },
                    can_edit: { type: :boolean },
                    can_delete: { type: :boolean },
                    can_recover: { type: :boolean },
                    can_wiki: { type: :boolean },
                    read: { type: :boolean },
                    user_title: { type: :string, nullable: true },
                    actions_summary: {
                      type: :array,
                      items: {
                        type: :object,
                        properties: {
                          id: { type: :integer },
                          can_act: { type: :boolean },
                        }
                      },
                    },
                    moderator: { type: :boolean },
                    admin: { type: :boolean },
                    staff: { type: :boolean },
                    user_id: { type: :integer },
                    hidden: { type: :boolean },
                    trust_level: { type: :integer },
                    deleted_at: { type: :string, nullable: true },
                    user_deleted: { type: :boolean },
                    edit_reason: { type: :string, nullable: true },
                    can_view_edit_history: { type: :boolean },
                    wiki: { type: :boolean },
                    reviewable_id: { type: :integer },
                    reviewable_score_count: { type: :integer },
                    reviewable_score_pending_count: { type: :integer },
                  }
                },
              },
            }
          },
          id: { type: :integer },
        }

        let(:post_body) { { 'post_ids[]': 1 } }
        let(:id) { Fabricate(:topic).id }

        run_test!
      end
    end
  end

  path '/t/{id}.json' do
    get 'Get a single topic' do
      tags 'Topics'
      consumes 'application/json'
      parameter name: 'Api-Key', in: :header, type: :string, required: true
      parameter name: 'Api-Username', in: :header, type: :string, required: true
      parameter name: :id, in: :path, schema: { type: :string }

      produces 'application/json'
      response '200', 'specific posts' do

        schema type: :object, properties: {
          post_stream: {
            type: :object,
            properties: {
              posts: {
                type: :array,
                items: {
                  type: :object,
                  properties: {
                    id: { type: :integer },
                    name: { type: :string },
                    username: { type: :string },
                    avatar_template: { type: :string },
                    created_at: { type: :string },
                    cooked: { type: :string },
                    post_number: { type: :integer },
                    post_type: { type: :integer },
                    updated_at: { type: :string },
                    reply_count: { type: :integer },
                    reply_to_post_number: { type: :string, nullable: true },
                    quote_count: { type: :integer },
                    incoming_link_count: { type: :integer },
                    reads: { type: :integer },
                    readers_count: { type: :integer },
                    score: { type: :number },
                    yours: { type: :boolean },
                    topic_id: { type: :integer },
                    topic_slug: { type: :string },
                    display_username: { type: :string },
                    primary_group_name: { type: :string, nullable: true },
                    flair_name: { type: :string, nullable: true },
                    flair_url: { type: :string, nullable: true },
                    flair_bg_color: { type: :string, nullable: true },
                    flair_color: { type: :string, nullable: true },
                    version: { type: :integer },
                    can_edit: { type: :boolean },
                    can_delete: { type: :boolean },
                    can_recover: { type: :boolean },
                    can_wiki: { type: :boolean },
                    link_counts: {
                      type: :array,
                      items: {
                        type: :object,
                        properties: {
                          url: { type: :string },
                          internal: { type: :boolean },
                          reflection: { type: :boolean },
                          clicks: { type: :integer },
                        }
                      },
                    },
                    read: { type: :boolean },
                    user_title: { type: :string, nullable: true },
                    actions_summary: {
                      type: :array,
                      items: {
                        type: :object,
                        properties: {
                          id: { type: :integer },
                          can_act: { type: :boolean },
                        }
                      },
                    },
                    moderator: { type: :boolean },
                    admin: { type: :boolean },
                    staff: { type: :boolean },
                    user_id: { type: :integer },
                    hidden: { type: :boolean },
                    trust_level: { type: :integer },
                    deleted_at: { type: :string, nullable: true },
                    user_deleted: { type: :boolean },
                    edit_reason: { type: :string, nullable: true },
                    can_view_edit_history: { type: :boolean },
                    wiki: { type: :boolean },
                    reviewable_id: { type: :integer },
                    reviewable_score_count: { type: :integer },
                    reviewable_score_pending_count: { type: :integer },
                  }
                },
              },
              stream: {
                type: :array,
                items: {
                },
              },
            }
          },
          timeline_lookup: {
            type: :array,
            items: {
            },
          },
          suggested_topics: {
            type: :array,
            items: {
              type: :object,
              properties: {
                id: { type: :integer },
                title: { type: :string },
                fancy_title: { type: :string },
                slug: { type: :string },
                posts_count: { type: :integer },
                reply_count: { type: :integer },
                highest_post_number: { type: :integer },
                image_url: { type: :string, nullable: true },
                created_at: { type: :string },
                last_posted_at: { type: :string, nullable: true },
                bumped: { type: :boolean },
                bumped_at: { type: :string },
                archetype: { type: :string },
                unseen: { type: :boolean },
                last_read_post_number: { type: :integer },
                unread_posts: { type: :integer },
                pinned: { type: :boolean },
                unpinned: { type: :boolean },
                visible: { type: :boolean },
                closed: { type: :boolean },
                archived: { type: :boolean },
                notification_level: { type: :integer },
                bookmarked: { type: :boolean },
                liked: { type: :boolean },
                like_count: { type: :integer },
                views: { type: :integer },
                category_id: { type: :integer },
                featured_link: { type: :string, nullable: true },
                posters: {
                  type: :array,
                  items: {
                    type: :object,
                    properties: {
                      extras: { type: :string, nullable: true },
                      description: { type: :string },
                      user: {
                        type: :object,
                        properties: {
                          id: { type: :integer },
                          username: { type: :string },
                          name: { type: :string },
                          avatar_template: { type: :string },
                        }
                      },
                    }
                  },
                },
              }
            },
          },
          id: { type: :integer },
          title: { type: :string },
          fancy_title: { type: :string },
          posts_count: { type: :integer },
          created_at: { type: :string },
          views: { type: :integer },
          reply_count: { type: :integer },
          like_count: { type: :integer },
          last_posted_at: { type: :string, nullable: true },
          visible: { type: :boolean },
          closed: { type: :boolean },
          archived: { type: :boolean },
          has_summary: { type: :boolean },
          archetype: { type: :string },
          slug: { type: :string },
          category_id: { type: :integer },
          word_count: { type: :integer, nullable: true },
          deleted_at: { type: :string, nullable: true },
          user_id: { type: :integer },
          featured_link: { type: :string, nullable: true },
          pinned_globally: { type: :boolean },
          pinned_at: { type: :string, nullable: true },
          pinned_until: { type: :string, nullable: true },
          image_url: { type: :string, nullable: true },
          draft: { type: :string, nullable: true },
          draft_key: { type: :string },
          draft_sequence: { type: :integer },
          unpinned: { type: :string, nullable: true },
          pinned: { type: :boolean },
          current_post_number: { type: :integer },
          highest_post_number: { type: :integer, nullable: true },
          deleted_by: { type: :string, nullable: true },
          has_deleted: { type: :boolean },
          actions_summary: {
            type: :array,
            items: {
              type: :object,
              properties: {
                id: { type: :integer },
                count: { type: :integer },
                hidden: { type: :boolean },
                can_act: { type: :boolean },
              }
            },
          },
          chunk_size: { type: :integer },
          bookmarked: { type: :boolean },
          topic_timer: { type: :string, nullable: true },
          message_bus_last_id: { type: :integer },
          participant_count: { type: :integer },
          show_read_indicator: { type: :boolean },
          thumbnails: { type: :string, nullable: true },
          details: {
            type: :object,
            properties: {
              notification_level: { type: :integer },
              can_move_posts: { type: :boolean },
              can_edit: { type: :boolean },
              can_delete: { type: :boolean },
              can_remove_allowed_users: { type: :boolean },
              can_create_post: { type: :boolean },
              can_reply_as_new_topic: { type: :boolean },
              can_flag_topic: { type: :boolean },
              can_convert_topic: { type: :boolean },
              can_review_topic: { type: :boolean },
              can_remove_self_id: { type: :integer },
              participants: {
                type: :array,
                items: {
                  type: :object,
                  properties: {
                    id: { type: :integer },
                    username: { type: :string },
                    name: { type: :string },
                    avatar_template: { type: :string },
                    post_count: { type: :integer },
                    primary_group_name: { type: :string, nullable: true },
                    flair_name: { type: :string, nullable: true },
                    flair_url: { type: :string, nullable: true },
                    flair_color: { type: :string, nullable: true },
                    flair_bg_color: { type: :string, nullable: true },
                  }
                },
              },
              created_by: {
                type: :object,
                properties: {
                  id: { type: :integer },
                  username: { type: :string },
                  name: { type: :string },
                  avatar_template: { type: :string },
                }
              },
              last_poster: {
                type: :object,
                properties: {
                  id: { type: :integer },
                  username: { type: :string },
                  name: { type: :string },
                  avatar_template: { type: :string },
                }
              },
            }
          },
        }
        let(:id) { Fabricate(:topic).id }

        run_test!
      end
    end

    delete 'Remove a topic' do
      tags 'Topics'
      consumes 'application/json'
      parameter name: 'Api-Key', in: :header, type: :string, required: true
      parameter name: 'Api-Username', in: :header, type: :string, required: true
      parameter name: :id, in: :path, schema: { type: :string }
      response '200', 'specific posts' do

        let!(:post) { Fabricate(:post) }
        let(:id) { post.topic.id }

        run_test!
      end
    end
  end

  path '/t/-/{id}.json' do
    put 'Update a topic' do
      tags 'Topics'
      consumes 'application/json'
      parameter name: 'Api-Key', in: :header, type: :string, required: true
      parameter name: 'Api-Username', in: :header, type: :string, required: true
      parameter name: :id, in: :path, schema: { type: :string }

      parameter name: :post_body, in: :body, schema: {
        type: :object,
        properties: {
          topic: {
            type: :object,
            properties: {
              title: { type: :string },
              category_id: { type: :integer },
            }
          }
        }
      }

      produces 'application/json'
      response '200', 'topic updated' do
        schema type: :object, properties: {
          basic_topic: {
            type: :object,
            properties: {
              id: { type: :integer },
              title: { type: :string },
              fancy_title: { type: :string },
              slug: { type: :string },
              posts_count: { type: :integer },
            }
          },
        }

        let(:post_body) { { title: 'New topic title' } }
        let!(:post) { Fabricate(:post) }
        let(:id) { post.topic.id }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['basic_topic']['title']).to eq("New topic title")
        end
      end
    end
  end

  path '/t/{id}/invite.json' do
    post 'Invite to topic' do
      tags 'Topics', 'Invites'
      consumes 'application/json'
      parameter name: 'Api-Key', in: :header, type: :string, required: true
      parameter name: 'Api-Username', in: :header, type: :string, required: true
      parameter name: :id, in: :path, schema: { type: :string }

      parameter name: :request_body, in: :body, schema: {
        type: :object,
        properties: {
          user: { type: :string },
          email: { type: :string },
        }
      }

      produces 'application/json'
      response '200', 'topic updated' do
        schema type: :object, properties: {
          user: {
            type: :object,
            properties: {
              id: { type: :integer },
              username: { type: :string },
              name: { type: :string },
              avatar_template: { type: :string },
            }
          },
        }

        let(:username) { Fabricate(:user).username }
        let(:request_body) { { user: username } }
        let(:id) { Fabricate(:topic).id }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['user']['username']).to eq(username)
        end
      end
    end
  end

  path '/t/{id}/bookmark.json' do
    put 'Bookmark topic' do
      tags 'Topics'
      consumes 'application/json'
      parameter name: 'Api-Key', in: :header, type: :string, required: true
      parameter name: 'Api-Username', in: :header, type: :string, required: true
      parameter name: :id, in: :path, schema: { type: :string }

      produces 'application/json'
      response '200', 'topic updated' do

        let!(:post) { Fabricate(:post) }
        let(:id) { post.topic.id }

        run_test!
      end
    end
  end

  path '/t/{id}/status.json' do
    put 'Update the status of a topic' do
      tags 'Topics'
      consumes 'application/json'
      parameter name: 'Api-Key', in: :header, type: :string, required: true
      parameter name: 'Api-Username', in: :header, type: :string, required: true
      parameter name: :id, in: :path, schema: { type: :string }

      parameter name: :request_body, in: :body, schema: {
        type: :object,
        properties: {
          status: {
            type: :string,
            enum: ['closed', 'pinned', 'pinned_globally', 'archived', 'visible'],
          },
          enabled: {
            type: :string,
            enum: ['true', 'false']
          },
          until: {
            type: :string,
            description: 'Only required for `pinned` and `pinned_globally`',
            example: '2030-12-31'
          }
        }, required: [ 'status', 'enabled' ]
      }

      produces 'application/json'
      response '200', 'topic updated' do
        schema type: :object, properties: {
          success: { type: :string, example: "OK" },
          topic_status_update: { type: :string, nullable: true },
        }

        let(:request_body) { { status: 'closed', enabled: 'true' } }
        let(:id) { Fabricate(:topic).id }

        run_test!
      end
    end
  end

  path '/latest.json' do
    get 'Get the latest topics' do
      tags 'Topics'
      consumes 'application/json'
      parameter name: 'Api-Key', in: :header, type: :string, required: true
      parameter name: 'Api-Username', in: :header, type: :string, required: true
      parameter(
        name: :order,
        in: :query,
        type: :string,
        description: 'Enum: `default`, `created`, `activity`, `views`, `posts`, `category`, `likes`, `op_likes`, `posters`')
      parameter(
        name: :ascending,
        in: :query,
        type: :string,
        description: 'Defaults to `desc`, add `ascending=true` to sort asc')

      produces 'application/json'
      response '200', 'topic updated' do
        schema type: :object, properties: {
          users: {
            type: :array,
            items: {
              type: :object,
              properties: {
                id: { type: :integer },
                username: { type: :string },
                name: { type: :string, nullable: true },
                avatar_template: { type: :string },
              }
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
              can_create_topic: { type: :boolean },
              draft: { type: :string, nullable: true },
              draft_key: { type: :string },
              draft_sequence: { type: :integer },
              per_page: { type: :integer },
              topics: {
                type: :array,
                items: {
                  type: :object,
                  properties: {
                    id: { type: :integer },
                    title: { type: :string },
                    fancy_title: { type: :string },
                    slug: { type: :string },
                    posts_count: { type: :integer },
                    reply_count: { type: :integer },
                    highest_post_number: { type: :integer },
                    image_url: { type: :string },
                    created_at: { type: :string },
                    last_posted_at: { type: :string },
                    bumped: { type: :boolean },
                    bumped_at: { type: :string },
                    archetype: { type: :string },
                    unseen: { type: :boolean },
                    last_read_post_number: { type: :integer },
                    unread_posts: { type: :integer },
                    pinned: { type: :boolean },
                    unpinned: { type: :string, nullable: true },
                    visible: { type: :boolean },
                    closed: { type: :boolean },
                    archived: { type: :boolean },
                    notification_level: { type: :integer },
                    bookmarked: { type: :boolean },
                    liked: { type: :boolean },
                    views: { type: :integer },
                    like_count: { type: :integer },
                    has_summary: { type: :boolean },
                    last_poster_username: { type: :string },
                    category_id: { type: :integer },
                    op_like_count: { type: :integer },
                    pinned_globally: { type: :boolean },
                    featured_link: { type: :string, nullable: true },
                    posters: {
                      type: :array,
                      items: {
                        type: :object,
                        properties: {
                          extras: { type: :string },
                          description: { type: :string },
                          user_id: { type: :integer },
                          primary_group_id: { type: :string, nullable: true },
                        }
                      },
                    },
                  }
                },
              },
            }
          },
        }

        let(:order) { 'default' }
        let(:ascending) { 'false' }

        run_test!
      end
    end
  end

  path '/top.json' do
    get 'Get the top topics' do
      tags 'Topics'
      consumes 'application/json'
      parameter name: 'Api-Key', in: :header, type: :string, required: true
      parameter name: 'Api-Username', in: :header, type: :string, required: true

      produces 'application/json'
      response '200', 'topic updated' do
        schema type: :object, properties: {
          users: {
            type: :array,
            items: {
              type: :object,
              properties: {
                id: { type: :integer },
                username: { type: :string },
                name: { type: :string },
                avatar_template: { type: :string },
              }
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
              can_create_topic: { type: :boolean },
              draft: { type: :string, nullable: true },
              draft_key: { type: :string },
              draft_sequence: { type: :integer },
              for_period: { type: :string },
              per_page: { type: :integer },
              topics: {
                type: :array,
                items: {
                  type: :object,
                  properties: {
                    id: { type: :integer },
                    title: { type: :string },
                    fancy_title: { type: :string },
                    slug: { type: :string },
                    posts_count: { type: :integer },
                    reply_count: { type: :integer },
                    highest_post_number: { type: :integer },
                    image_url: { type: :string, nullable: true },
                    created_at: { type: :string },
                    last_posted_at: { type: :string },
                    bumped: { type: :boolean },
                    bumped_at: { type: :string },
                    archetype: { type: :string },
                    unseen: { type: :boolean },
                    last_read_post_number: { type: :integer },
                    unread_posts: { type: :integer },
                    pinned: { type: :boolean },
                    unpinned: { type: :boolean },
                    visible: { type: :boolean },
                    closed: { type: :boolean },
                    archived: { type: :boolean },
                    notification_level: { type: :integer },
                    bookmarked: { type: :boolean },
                    liked: { type: :boolean },
                    views: { type: :integer },
                    like_count: { type: :integer },
                    has_summary: { type: :boolean },
                    last_poster_username: { type: :string },
                    category_id: { type: :integer },
                    op_like_count: { type: :integer },
                    pinned_globally: { type: :boolean },
                    featured_link: { type: :string, nullable: true },
                    posters: {
                      type: :array,
                      items: {
                        type: :object,
                        properties: {
                          extras: { type: :string, nullable: true },
                          description: { type: :string },
                          user_id: { type: :integer },
                          primary_group_id: { type: :string, nullable: true },
                        }
                      },
                    },
                  }
                },
              },
            }
          },
        }

        run_test!
      end
    end
  end

  path '/top.json?period={flag}' do
    get 'Get the top topics filtered by a flag' do
      tags 'Topics'
      consumes 'application/json'
      parameter name: 'Api-Key', in: :header, type: :string, required: true
      parameter name: 'Api-Username', in: :header, type: :string, required: true
      parameter(
        name: :flag,
        in: :path,
        type: :string,
        description: 'Enum: `all`, `yearly`, `quarterly`, `monthly`, `weekly`, `daily`')

      produces 'application/json'
      response '200', 'response' do
        schema type: :object, properties: {
          users: {
            type: :array,
            items: {
              type: :object,
              properties: {
                id: { type: :integer },
                username: { type: :string },
                name: { type: :string },
                avatar_template: { type: :string },
              }
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
              can_create_topic: { type: :boolean },
              draft: { type: :string, nullable: true },
              draft_key: { type: :string },
              draft_sequence: { type: :integer },
              for_period: { type: :string },
              per_page: { type: :integer },
              topics: {
                type: :array,
                items: {
                  type: :object,
                  properties: {
                    id: { type: :integer },
                    title: { type: :string },
                    fancy_title: { type: :string },
                    slug: { type: :string },
                    posts_count: { type: :integer },
                    reply_count: { type: :integer },
                    highest_post_number: { type: :integer },
                    image_url: { type: :string, nullable: true },
                    created_at: { type: :string },
                    last_posted_at: { type: :string },
                    bumped: { type: :boolean },
                    bumped_at: { type: :string },
                    archetype: { type: :string },
                    unseen: { type: :boolean },
                    last_read_post_number: { type: :integer },
                    unread_posts: { type: :integer },
                    pinned: { type: :boolean },
                    unpinned: { type: :boolean },
                    visible: { type: :boolean },
                    closed: { type: :boolean },
                    archived: { type: :boolean },
                    notification_level: { type: :integer },
                    bookmarked: { type: :boolean },
                    liked: { type: :boolean },
                    views: { type: :integer },
                    like_count: { type: :integer },
                    has_summary: { type: :boolean },
                    last_poster_username: { type: :string },
                    category_id: { type: :integer },
                    op_like_count: { type: :integer },
                    pinned_globally: { type: :boolean },
                    featured_link: { type: :string, nullable: true },
                    posters: {
                      type: :array,
                      items: {
                        type: :object,
                        properties: {
                          extras: { type: :string, nullable: true },
                          description: { type: :string },
                          user_id: { type: :integer },
                          primary_group_id: { type: :string, nullable: true },
                        }
                      },
                    },
                  }
                },
              },
            }
          },
        }

        let(:flag) { 'all' }

        run_test!
      end
    end
  end

  path '/t/{id}/notifications.json' do
    post 'Set notification level' do
      tags 'Topics'
      consumes 'application/json'
      parameter name: 'Api-Key', in: :header, type: :string, required: true
      parameter name: 'Api-Username', in: :header, type: :string, required: true
      parameter name: :id, in: :path, schema: { type: :string }

      parameter name: :request_body, in: :body, schema: {
        type: :object,
        properties: {
          notification_level: {
            type: :string,
            enum: ['0', '1', '2', '3'],
          }
        }, required: [ 'notification_level' ]
      }

      produces 'application/json'
      response '200', 'topic updated' do
        schema type: :object, properties: {
          success: { type: :string, example: "OK" }
        }

        let(:request_body) { { notification_level: '3' } }
        let(:id) { Fabricate(:topic).id }

        run_test!
      end
    end
  end

  path '/t/{id}/change-timestamp.json' do
    put 'Update topic timestamp' do
      tags 'Topics'
      consumes 'application/json'
      parameter name: 'Api-Key', in: :header, type: :string, required: true
      parameter name: 'Api-Username', in: :header, type: :string, required: true
      parameter name: :id, in: :path, schema: { type: :string }

      parameter name: :request_body, in: :body, schema: {
        type: :object,
        properties: {
          timestamp: {
            type: :string,
            example: '1594291380'
          }
        }, required: [ 'timestamp' ]
      }

      produces 'application/json'
      response '200', 'topic updated' do
        schema type: :object, properties: {
          success: { type: :string, example: "OK" }
        }

        let(:request_body) { { timestamp: '1594291380' } }
        let!(:post) { Fabricate(:post) }
        let(:id) { post.topic.id }

        run_test!
      end
    end
  end

  path '/t/{id}/timer.json' do
    post 'Create topic timer' do
      tags 'Topics'
      consumes 'application/json'
      parameter name: 'Api-Key', in: :header, type: :string, required: true
      parameter name: 'Api-Username', in: :header, type: :string, required: true
      parameter name: :id, in: :path, schema: { type: :string }

      parameter name: :request_body, in: :body, schema: {
        type: :object,
        properties: {
          time: {
            type: :string,
            example: ''
          },
          status_type: {
            type: :string,
          },
          based_on_last_post: {
            type: :boolean,
          },
          category_id: {
            type: :integer
          }
        }
      }

      produces 'application/json'
      response '200', 'topic updated' do
        schema type: :object, properties: {
          success: { type: :string, example: "OK" },
          execute_at: { type: :string },
          duration: { type: :string, nullable: true },
          based_on_last_post: { type: :boolean },
          closed: { type: :boolean },
          category_id: { type: :string, nullable: true },
        }

        let(:request_body) { { time: Time.current + 1.day, status_type: 'close' } }
        let!(:topic_post) { Fabricate(:post) }
        let(:id) { topic_post.topic.id }

        run_test!
      end
    end
  end

end
