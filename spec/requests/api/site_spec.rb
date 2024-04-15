# frozen_string_literal: true
require "swagger_helper"

RSpec.describe "site" do
  fab!(:admin)
  fab!(:category)
  fab!(:subcategory) { Fabricate(:category, parent_category: category) }

  before do
    Jobs.run_immediately!
    sign_in(admin)
  end

  path "/site.json" do
    get "Get site info" do
      tags "Site", "Categories"
      operationId "getSite"
      description "Can be used to fetch all categories and subcategories"
      consumes "application/json"
      expected_request_schema = nil

      produces "application/json"
      response "200", "success response" do
        begin
          Site.preloaded_category_custom_fields << "no_oddjob"

          expected_response_schema = load_spec_schema("site_response")
          schema expected_response_schema

          it_behaves_like "a JSON endpoint", 200 do
            let(:expected_response_schema) { expected_response_schema }
            let(:expected_request_schema) { expected_request_schema }
          end
        ensure
          Site.reset_preloaded_category_custom_fields
        end
      end
    end
  end

  path "/site/basic-info.json" do
    get "Get site basic info" do
      tags "Site"
      operationId "getSiteBasicInfo"
      description "Can be used to fetch basic info about a site"
      consumes "application/json"
      expected_request_schema = nil

      produces "application/json"
      response "200", "success response" do
        expected_response_schema = load_spec_schema("site_basic_info_response")
        schema expected_response_schema

        it_behaves_like "a JSON endpoint", 200 do
          let(:expected_response_schema) { expected_response_schema }
          let(:expected_request_schema) { expected_request_schema }
        end
      end
    end
  end
end
