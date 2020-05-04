# frozen_string_literal: true
require 'swagger_helper'

describe 'categories' do

  let(:admin) { Fabricate(:admin) }

  before do
    Jobs.run_immediately!
    sign_in(admin)
  end

  path '/categories.json' do

    post 'Creates a category' do
      before do
        Jobs.run_immediately!
        sign_in(admin)
      end
      tags 'Category'
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
              },
              required: ["id"]
            }
          }, required: ["category"]

        let(:category) { { name: 'todo', color: 'f94cb0', text_color: '412763' } }
        run_test!
      end
    end

    get 'Retreives a list of categories' do
      tags 'Category'
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
              categories: { type: :array },
            }, required: ["categories"]
          }
        }, required: ["category_list"]
        run_test!
      end
    end
  end
end
