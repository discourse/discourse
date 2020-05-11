# frozen_string_literal: true
require 'swagger_helper'

describe 'posts' do

  let(:'Api-Key') { Fabricate(:api_key).key }
  let(:'Api-Username') { 'system' }

  path '/posts.json' do

    get 'List latest posts across topics' do
      tags 'Posts'
      parameter name: 'Api-Key', in: :header, type: :string, required: true
      parameter name: 'Api-Username', in: :header, type: :string, required: true
      produces 'application/json'

      response '200', 'latest posts' do
        schema type: :object, properties: {
          latest_posts: {
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
                topic_title: { type: :string },
                topic_html_title: { type: :string },
                category_id: { type: :integer },
                display_username: { type: :string },
                primary_group_name: { type: :string, nullable: true },
                primary_group_flair_url: { type: :string, nullable: true },
                primary_group_flair_bg_color: { type: :string, nullable: true },
                primary_group_flair_color: { type: :string, nullable: true },
                version: { type: :integer },
                can_edit: { type: :boolean },
                can_delete: { type: :boolean },
                can_recover: { type: :boolean },
                can_wiki: { type: :boolean },
                user_title: { type: :string, nullable: true },
                raw: { type: :string },
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
                reviewable_id: { type: :string, nullable: true },
                reviewable_score_count: { type: :integer },
                reviewable_score_pending_count: { type: :integer },
              }
            },
          },
        }

        let!(:post) { Fabricate(:post) }
        run_test!
      end
    end

    post 'Creates a new topic, a new post, or a private message' do
      tags 'Posts'
      consumes 'application/json'
      parameter name: 'Api-Key', in: :header, type: :string, required: true
      parameter name: 'Api-Username', in: :header, type: :string, required: true
      # Can't be named :post!
      parameter name: :post_body, in: :body, schema: {
        type: :object,
        properties: {
          title: {
            type: :string,
            description: 'Required if creating a new topic or new private message.'
          },
          topic_id: {
            type: :integer,
            description: 'Required if creating a new post.'
          },
          raw: { type: :string },
          category: {
            type: :integer,
            description: 'Optional if creating a new topic, and ignored if creating a new post.'
          },
          target_usernames: {
            type: :string,
            description: 'Required for private message, comma separated.',
            example: 'blake,sam'
          },
          archetype: { type: :string },
          created_at: { type: :string },
        },
        required: [ 'raw' ]
      }

      produces 'application/json'
      response '200', 'post created' do
        schema type: :object, properties: {
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
          primary_group_flair_url: { type: :string, nullable: true },
          primary_group_flair_bg_color: { type: :string, nullable: true },
          primary_group_flair_color: { type: :string, nullable: true },
          version: { type: :integer },
          can_edit: { type: :boolean },
          can_delete: { type: :boolean },
          can_recover: { type: :boolean },
          can_wiki: { type: :boolean },
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
          draft_sequence: { type: :integer },
          hidden: { type: :boolean },
          trust_level: { type: :integer },
          deleted_at: { type: :string, nullable: true },
          user_deleted: { type: :boolean },
          edit_reason: { type: :string, nullable: true },
          can_view_edit_history: { type: :boolean },
          wiki: { type: :boolean },
          reviewable_id: { type: :string, nullable: true },
          reviewable_score_count: { type: :integer },
          reviewable_score_pending_count: { type: :integer },
        }

        let(:post_body) { Fabricate(:post) }
        run_test!
      end
    end
  end

  path '/posts/{id}.json' do

    get 'Retreive a single post' do
      tags 'Posts'
      parameter name: 'Api-Key', in: :header, type: :string, required: true
      parameter name: 'Api-Username', in: :header, type: :string, required: true
      parameter name: :id, in: :path, schema: { type: :string }

      produces 'application/json'

      response '200', 'latest posts' do
        schema type: :object, properties: {
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
          primary_group_flair_url: { type: :string, nullable: true },
          primary_group_flair_bg_color: { type: :string, nullable: true },
          primary_group_flair_color: { type: :string, nullable: true },
          version: { type: :integer },
          can_edit: { type: :boolean },
          can_delete: { type: :boolean },
          can_recover: { type: :boolean },
          can_wiki: { type: :boolean },
          user_title: { type: :string, nullable: true },
          raw: { type: :string },
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
          reviewable_id: { type: :string, nullable: true },
          reviewable_score_count: { type: :integer },
          reviewable_score_pending_count: { type: :integer },
        }

        let(:id) { Fabricate(:post).id }
        run_test!
      end
    end

    put 'Update a single post' do
      tags 'Posts'
      consumes 'application/json'
      parameter name: 'Api-Key', in: :header, type: :string, required: true
      parameter name: 'Api-Username', in: :header, type: :string, required: true
      parameter name: :id, in: :path, schema: { type: :string }

      parameter name: :post_body, in: :body, schema: {
        type: :object,
        properties: {
          post: {
            type: :object,
            properties: {
              raw: { type: :string },
              edit_reason: { type: :string },
            }, required: [ 'raw' ]
          }
        }
      }

      produces 'application/json'
      response '200', 'post updated' do
        schema type: :object, properties: {
          post: {
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
              score: { type: :number },
              yours: { type: :boolean },
              topic_id: { type: :integer },
              topic_slug: { type: :string },
              display_username: { type: :string, nullable: true },
              primary_group_name: { type: :string, nullable: true },
              primary_group_flair_url: { type: :string, nullable: true },
              primary_group_flair_bg_color: { type: :string, nullable: true },
              primary_group_flair_color: { type: :string, nullable: true },
              version: { type: :integer },
              can_edit: { type: :boolean },
              can_delete: { type: :boolean },
              can_recover: { type: :boolean },
              can_wiki: { type: :boolean },
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
              draft_sequence: { type: :integer },
              hidden: { type: :boolean },
              trust_level: { type: :integer },
              deleted_at: { type: :string, nullable: true },
              user_deleted: { type: :boolean },
              edit_reason: { type: :string, nullable: true },
              can_view_edit_history: { type: :boolean },
              wiki: { type: :boolean },
              reviewable_id: { type: :string, nullable: true },
              reviewable_score_count: { type: :integer },
              reviewable_score_pending_count: { type: :integer },
            }
          },
        }

        let(:post_body) { { 'post': { 'raw': 'Updated content!', 'edit_reason': 'fixed typo' } } }
        let(:id) { Fabricate(:post).id }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['post']['cooked']).to eq("<p>Updated content!</p>")
          expect(data['post']['edit_reason']).to eq("fixed typo")
        end
      end
    end
  end

  path '/posts/{id}/locked.json' do
    put 'Lock a post from being edited' do
      tags 'Posts'
      consumes 'application/json'
      parameter name: 'Api-Key', in: :header, type: :string, required: true
      parameter name: 'Api-Username', in: :header, type: :string, required: true
      parameter name: :id, in: :path, schema: { type: :string }

      parameter name: :post_body, in: :body, schema: {
        type: :object,
        properties: {
          locked: { type: :boolean }
        }, required: [ 'locked' ]
      }

      produces 'application/json'
      response '200', 'post updated' do
        schema type: :object, properties: {
          locked: { type: :boolean },
        }

        let(:post_body) { { 'locked': 'true' } }
        let(:id) { Fabricate(:post).id }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['locked']).to eq(true)
        end
      end
    end
  end

  path '/post_actions.json' do
    post 'Like a post and other actions' do
      tags 'Posts'
      consumes 'application/json'
      parameter name: 'Api-Key', in: :header, type: :string, required: true
      parameter name: 'Api-Username', in: :header, type: :string, required: true

      parameter name: :post_body, in: :body, schema: {
        type: :object,
        properties: {
          id: { type: :integer },
          post_action_type_id: { type: :integer },
          flag_topic: { type: :boolean },
        }, required: [ 'id', 'post_action_type_id' ]
      }

      produces 'application/json'
      response '200', 'post updated' do
        schema type: :object, properties: {
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
          primary_group_flair_url: { type: :string, nullable: true },
          primary_group_flair_bg_color: { type: :string, nullable: true },
          primary_group_flair_color: { type: :string, nullable: true },
          version: { type: :integer },
          can_edit: { type: :boolean },
          can_delete: { type: :boolean },
          can_recover: { type: :boolean },
          can_wiki: { type: :boolean },
          user_title: { type: :string, nullable: true },
          actions_summary: {
            type: :array,
            items: {
              type: :object,
              properties: {
                id: { type: :integer },
                count: { type: :integer },
                acted: { type: :boolean },
                can_undo: { type: :boolean },
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
          notice_type: { type: :string },
          reviewable_id: { type: :string, nullable: true },
          reviewable_score_count: { type: :integer },
          reviewable_score_pending_count: { type: :integer },
        }

        let(:id) { Fabricate(:post).id }
        let(:post_body) { { id: id, post_action_type_id: 2 } }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['actions_summary'][0]['id']).to eq(2)
          expect(data['actions_summary'][0]['count']).to eq(1)
        end
      end
    end
  end

end
