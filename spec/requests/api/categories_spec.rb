# frozen_string_literal: true
require 'swagger_helper'

describe 'categories' do

  let(:admin) { Fabricate(:admin) }
  let!(:category) { Fabricate(:category, user: admin) }

  before do
    Jobs.run_immediately!
    sign_in(admin)
  end

  path '/categories.json' do

    post 'Creates a category' do
      tags 'Categories'
      consumes 'application/json'
      parameter name: :category, in: :body, schema: {
        type: :object,
        properties: {
          name: { type: :string },
          color: { type: :string },
          text_color: { type: :string },
        },
        required: [ 'name', 'color', 'text_color' ]
      }

      produces 'application/json'
      response '200', 'category created' do
        schema type: :object, properties: {
            category: {
              type: :object,
              properties: {
                id: { type: :integer },
                name: { type: :string },
                color: { type: :string },
                text_color: { type: :string },
                slug: { type: :string },
                topic_count: { type: :integer },
                post_count: { type: :integer },
                position: { type: :integer },
                description: { type: :string, nullable: true },
                description_text: { type: :string, nullable: true },
                topic_url: { type: :string },
                read_restricted: { type: :boolean },
                permission: { type: :integer, nullable: true },
                notification_level: { type: :integer, nullable: true },
                can_edit: { type: :boolean },
                topic_template: { type: :string, nullable: true },
                has_children: { type: :boolean, nullable: true },
                sort_order: { type: :string, nullable: true },
                show_subcategory_list: { type: :boolean },
                num_featured_topics: { type: :integer },
                default_view: { type: :string, nullable: true },
                subcategory_list_style: { type: :string },
                default_topic_period: { type: :string },
                minimum_required_tags: { type: :integer },
                navigate_to_first_post_after_read: { type: :boolean },
                custom_fields: { type: :object },
                min_tags_from_required_group: { type: :integer },
                required_tag_group_name: { type: :string, nullable: true },
                available_groups: { type: :array },
                auto_close_hours: { type: :integer, nullable: true },
                auto_close_based_on_last_post: { type: :boolean },
                group_permissions: { type: :array },
                email_in: { type: :boolean, nullable: true },
                email_in_allow_strangers: { type: :boolean },
                mailinglist_mirror: { type: :boolean },
                all_topics_wiki: { type: :boolean },
                can_delete: { type: :boolean },
                cannot_delete_reason: { type: :string, nullable: true },
                allow_badges: { type: :boolean },
                topic_featured_link_allowed: { type: :boolean },
                search_priority: { type: :integer },
                uploaded_logo: { type: :string, nullable: true },
                uploaded_background: { type: :string, nullable: true },
              },
              required: ["id"]
            }
          }, required: ["category"]

        let(:category) { { name: 'todo', color: 'f94cb0', text_color: '412763' } }
        run_test!
      end
    end

    get 'Retreives a list of categories' do
      tags 'Categories'
      produces 'application/json'

      response '200', 'categories response' do
        schema type: :object, properties: {
          category_list: {
            type: :object,
            properties: {
              can_create_category: { type: :boolean },
              can_create_topic: { type: :boolean },
              draft: { type: :string, nullable: true },
              draft_key: { type: :string },
              draft_sequence: { type: :integer },
              categories: {
                type: :array,
                items: {
                  type: :object,
                  properties: {
                    id: { type: :integer },
                    name: { type: :string },
                    color: { type: :string },
                    text_color: { type: :string },
                    slug: { type: :string },
                    topic_count: { type: :integer },
                    post_count: { type: :integer },
                    position: { type: :integer },
                    description: { type: :string, nullable: true },
                    description_text: { type: :string, nullable: true },
                    topic_url: { type: :string, nullable: true },
                    read_restricted: { type: :boolean },
                    permission: { type: :integer, nullable: true },
                    notification_level: { type: :integer, nullable: true },
                    can_edit: { type: :boolean },
                    topic_template: { type: :string, nullable: true },
                    has_children: { type: :boolean, nullable: true },
                    sort_order: { type: :string, nullable: true },
                    show_subcategory_list: { type: :boolean },
                    num_featured_topics: { type: :integer },
                    default_view: { type: :string, nullable: true },
                    subcategory_list_style: { type: :string },
                    default_topic_period: { type: :string },
                    minimum_required_tags: { type: :integer },
                    navigate_to_first_post_after_read: { type: :boolean },
                    topics_day: { type: :integer },
                    topics_week: { type: :integer },
                    topics_month: { type: :integer },
                    topics_year: { type: :integer },
                    topics_all_time: { type: :integer },
                    uploaded_logo: { type: :string, nullable: true },
                    uploaded_background: { type: :string, nullable: true },
                  }
                }
              },
            }, required: ["categories"]
          }
        }, required: ["category_list"]
        run_test!
      end
    end
  end

  path '/categories/{category_id}.json' do

    put 'Updates a category' do
      tags 'Categories'
      consumes 'application/json'
      parameter name: :category_id, in: :path, schema: { type: :string }
      parameter name: :category, in: :body, schema: {
        type: :object,
        properties: {
          name: { type: :string },
          color: { type: :string },
          text_color: { type: :string },
        },
        required: [ 'name', 'color', 'text_color' ]
      }

      produces 'application/json'
      response '200', 'category created' do
        schema type: :object, properties: {
          success: { type: :string },
          category: {
            type: :object,
            properties: {
              id: { type: :integer },
              name: { type: :string },
              color: { type: :string },
              text_color: { type: :string },
              slug: { type: :string },
              topic_count: { type: :integer },
              post_count: { type: :integer },
              position: { type: :integer },
              description: { type: :string, nullable: true },
              description_text: { type: :string, nullable: true },
              description_excerpt: { type: :string, nullable: true },
              topic_url: { type: :string, nullable: true },
              read_restricted: { type: :boolean },
              permission: { type: :string, nullable: true },
              notification_level: { type: :integer, nullable: true },
              can_edit: { type: :boolean },
              topic_template: { type: :string, nullable: true },
              has_children: { type: :string, nullable: true },
              sort_order: { type: :string, nullable: true },
              sort_ascending: { type: :string, nullable: true },
              show_subcategory_list: { type: :boolean },
              num_featured_topics: { type: :integer },
              default_view: { type: :string, nullable: true },
              subcategory_list_style: { type: :string },
              default_top_period: { type: :string },
              default_list_filter: { type: :string },
              minimum_required_tags: { type: :integer },
              navigate_to_first_post_after_read: { type: :boolean },
              custom_fields: {
                type: :object,
                properties: {
                }
              },
              min_tags_from_required_group: { type: :integer },
              required_tag_group_name: { type: :string, nullable: true },
              available_groups: {
                type: :array,
                items: {
                },
              },
              auto_close_hours: { type: :string, nullable: true },
              auto_close_based_on_last_post: { type: :boolean },
              group_permissions: {
                type: :array,
                items: {
                  type: :object,
                  properties: {
                    permission_type: { type: :integer },
                    group_name: { type: :string },
                  }
                },
              },
              email_in: { type: :string, nullable: true },
              email_in_allow_strangers: { type: :boolean },
              mailinglist_mirror: { type: :boolean },
              all_topics_wiki: { type: :boolean },
              can_delete: { type: :boolean },
              cannot_delete_reason: { type: :string, nullable: true },
              allow_badges: { type: :boolean },
              topic_featured_link_allowed: { type: :boolean },
              search_priority: { type: :integer },
              uploaded_logo: { type: :string, nullable: true },
              uploaded_background: { type: :string, nullable: true },
            }
          },
        }

        let(:category_id) { category.id }
        run_test!
      end
    end
  end

  path '/c/{category_id}.json' do

    get 'List topics' do
      tags 'Categories'
      produces 'application/json'
      parameter name: :category_id, in: :path, schema: { type: :string }

      response '200', 'response' do
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
            }
          },
          primary_groups: {
            type: :array
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
                    pinned: { type: :boolean },
                    unpinned: { type: :boolean, nullable: true },
                    excerpt: { type: :string },
                    visible: { type: :boolean },
                    closed: { type: :boolean },
                    archived: { type: :boolean },
                    bookmarked: { type: :boolean, nullable: true },
                    liked: { type: :boolean, nullable: true },
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
                          primary_group_id: { type: :integer, nullable: true },
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
        let(:category_id) { category.id }
        run_test!
      end
    end
  end

  path '/c/{category_id}/show.json' do

    get 'Show category' do
      tags 'Categories'
      produces 'application/json'
      parameter name: :category_id, in: :path, schema: { type: :string }

      response '200', 'response' do
        schema type: :object, properties: {
          category: {
            type: :object,
            properties: {
              id: { type: :integer },
              name: { type: :string },
              color: { type: :string },
              text_color: { type: :string },
              slug: { type: :string },
              topic_count: { type: :integer },
              post_count: { type: :integer },
              position: { type: :integer },
              description: { type: :string, nullable: true },
              description_text: { type: :string, nullable: true },
              description_excerpt: { type: :string, nullable: true },
              topic_url: { type: :string, nullable: true },
              read_restricted: { type: :boolean },
              permission: { type: :integer },
              notification_level: { type: :integer, nullable: true },
              can_edit: { type: :boolean },
              topic_template: { type: :string, nullable: true },
              has_children: { type: :string, nullable: true },
              sort_order: { type: :string, nullable: true },
              sort_ascending: { type: :string, nullable: true },
              show_subcategory_list: { type: :boolean },
              num_featured_topics: { type: :integer },
              default_view: { type: :string, nullable: true },
              subcategory_list_style: { type: :string },
              default_top_period: { type: :string },
              default_list_filter: { type: :string },
              minimum_required_tags: { type: :integer },
              navigate_to_first_post_after_read: { type: :boolean },
              custom_fields: {
                type: :object,
                properties: {
                }
              },
              min_tags_from_required_group: { type: :integer },
              required_tag_group_name: { type: :string, nullable: true },
              available_groups: {
                type: :array,
                items: {
                },
              },
              auto_close_hours: { type: :string, nullable: true },
              auto_close_based_on_last_post: { type: :boolean },
              group_permissions: {
                type: :array,
                items: {
                  type: :object,
                  properties: {
                    permission_type: { type: :integer },
                    group_name: { type: :string },
                  }
                },
              },
              email_in: { type: :string, nullable: true },
              email_in_allow_strangers: { type: :boolean },
              mailinglist_mirror: { type: :boolean },
              all_topics_wiki: { type: :boolean },
              can_delete: { type: :boolean },
              cannot_delete_reason: { type: :string, nullable: true },
              allow_badges: { type: :boolean },
              topic_featured_link_allowed: { type: :boolean },
              search_priority: { type: :integer },
              uploaded_logo: { type: :string, nullable: true },
              uploaded_background: { type: :string, nullable: true },
            }
          },
        }
        let(:category_id) { category.id }
        run_test!
      end
    end
  end

end
