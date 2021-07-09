# frozen_string_literal: true
require 'swagger_helper'

describe 'private messages' do

  let(:admin) { Fabricate(:admin) }

  before do
    Jobs.run_immediately!
    sign_in(admin)
  end

  path '/topics/private-messages/{username}.json' do

    get 'Get a list of private messages for a user' do
      tags 'Private Messages'
      parameter name: :username, in: :path, schema: { type: :string }

      produces 'application/json'
      response '200', 'private messages' do
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
                    category_id: { type: :string, nullable: true },
                    pinned_globally: { type: :boolean },
                    featured_link: { type: :string, nullable: true },
                    allowed_user_count: { type: :integer },
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
                    participants: {
                      type: :array,
                      items: {
                        type: :object,
                        properties: {
                          extras: { type: :string },
                          description: { type: :string, nullable: true },
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

        let(:username) { Fabricate(:user).username }
        run_test!
      end
    end

  end

  path '/topics/private-messages-sent/{username}.json' do

    get 'Get a list of private messages sent for a user' do
      tags 'Private Messages'
      parameter name: :username, in: :path, schema: { type: :string }

      produces 'application/json'
      response '200', 'private messages' do
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
                    category_id: { type: :string, nullable: true },
                    pinned_globally: { type: :boolean },
                    featured_link: { type: :string, nullable: true },
                    allowed_user_count: { type: :integer },
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
                    participants: {
                      type: :array,
                      items: {
                      },
                    },
                  }
                },
              },
            }
          },
        }

        let(:username) { Fabricate(:user).username }
        run_test!
      end
    end
  end
end
