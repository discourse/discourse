# frozen_string_literal: true
require_relative "../../swagger_helper"

RSpec.describe "categories" do
  let(:admin) { Fabricate(:admin) }
  let!(:category) { Fabricate(:category, user: admin) }

  before do
    Jobs.run_immediately!
    sign_in(admin)
  end

  path "/categories.json" do
    post "Creates a category" do
      tags "Categories"
      operationId "createCategory"
      consumes "application/json"
      expected_request_schema = load_spec_schema("category_create_request")
      parameter name: :params, in: :body, schema: expected_request_schema

      produces "application/json"
      response "200", "success response" do
        expected_response_schema = load_spec_schema("category_create_response")
        schema expected_response_schema

        let(:params) { { "name" => "todo" } }

        it_behaves_like "a JSON endpoint", 200 do
          let(:expected_response_schema) { expected_response_schema }
          let(:expected_request_schema) { expected_request_schema }
        end
      end
    end

    get "Retrieves a list of categories" do
      tags "Categories"
      operationId "listCategories"
      consumes "application/json"
      expected_request_schema = nil
      parameter name: :include_subcategories, in: :query, schema: { type: :boolean, enum: [true] }

      produces "application/json"
      response "200", "success response" do
        expected_response_schema = load_spec_schema("category_list_response")
        schema expected_response_schema

        let(:include_subcategories) { true }

        it_behaves_like "a JSON endpoint", 200 do
          let(:expected_response_schema) { expected_response_schema }
          let(:expected_request_schema) { expected_request_schema }
        end
      end
    end
  end

  path "/categories/{id}.json" do
    put "Updates a category" do
      tags "Categories"
      operationId "updateCategory"
      consumes "application/json"
      expected_request_schema = load_spec_schema("category_create_request")
      parameter name: :id, in: :path, schema: { type: :integer }
      parameter name: :params, in: :body, schema: expected_request_schema

      produces "application/json"
      response "200", "success response" do
        expected_response_schema = load_spec_schema("category_update_response")
        schema expected_response_schema

        let(:id) { category.id }
        let(:params) { { "name" => "todo" } }

        it_behaves_like "a JSON endpoint", 200 do
          let(:expected_response_schema) { expected_response_schema }
          let(:expected_request_schema) { expected_request_schema }
        end
      end
    end
  end

  path "/c/{slug}/{id}.json" do
    get "List topics" do
      tags "Categories"
      operationId "listCategoryTopics"
      produces "application/json"
      parameter name: :slug, in: :path, schema: { type: :string }
      parameter name: :id, in: :path, schema: { type: :integer }
      expected_request_schema = nil

      produces "application/json"
      response "200", "success response" do
        expected_response_schema = load_spec_schema("category_topics_response")
        schema expected_response_schema

        let(:id) { category.id }
        let(:slug) { category.slug_path.join("/") }

        it_behaves_like "a JSON endpoint", 200 do
          let(:expected_response_schema) { expected_response_schema }
          let(:expected_request_schema) { expected_request_schema }
        end
      end
    end
  end

  path "/c/{id}/show.json" do
    get "Show category" do
      tags "Categories"
      operationId "getCategory"
      consumes "application/json"
      parameter name: :id, in: :path, schema: { type: :integer }
      expected_request_schema = nil

      produces "application/json"
      response "200", "response" do
        expected_response_schema = load_spec_schema("category_create_response")
        schema expected_response_schema

        let(:id) { category.id }

        it_behaves_like "a JSON endpoint", 200 do
          let(:expected_response_schema) { expected_response_schema }
          let(:expected_request_schema) { expected_request_schema }
        end
      end
    end
  end
end
