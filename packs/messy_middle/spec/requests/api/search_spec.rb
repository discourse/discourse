# frozen_string_literal: true
require_relative "../../swagger_helper"

RSpec.describe "groups" do
  let(:admin) { Fabricate(:admin) }

  before do
    Jobs.run_immediately!
    sign_in(admin)
  end

  path "/search.json" do
    get "Search for a term" do
      tags "Search"
      operationId "search"
      consumes "application/json"
      parameter(
        name: :q,
        in: :query,
        type: :string,
        example:
          "api @blake #support tags:api after:2021-06-04 in:unseen in:open order:latest_topic",
        description: <<~MD,
          The query string needs to be url encoded and is made up of the following options:
          - Search term. This is just a string. Usually it would be the first item in the query.
          - `@<username>`: Use the `@` followed by the username to specify posts by this user.
          - `#<category>`: Use the `#` followed by the category slug to search within this category.
          - `tags:`: `api,solved` or for posts that have all the specified tags `api+solved`.
          - `before:`: `yyyy-mm-dd`
          - `after:`: `yyyy-mm-dd`
          - `order:`: `latest`, `likes`, `views`, `latest_topic`
          - `assigned:`: username (without `@`)
          - `in:`: `title`, `likes`, `personal`, `messages`, `seen`, `unseen`, `posted`, `created`, `watching`, `tracking`, `bookmarks`, `assigned`, `unassigned`, `first`, `pinned`, `wiki`
          - `with:`: `images`
          - `status:`: `open`, `closed`, `public`, `archived`, `noreplies`, `single_user`, `solved`, `unsolved`
          - `group:`: group_name or group_id
          - `group_messages:`: group_name or group_id
          - `min_posts:`: 1
          - `max_posts:`: 10
          - `min_views:`: 1
          - `max_views:`: 10

          If you are using cURL you can use the `-G` and the `--data-urlencode` flags to encode the query:

          ```
          curl -i -sS -X GET -G "http://localhost:4200/search.json" \\
          --data-urlencode 'q=wordpress @scossar #fun after:2020-01-01'
          ```
        MD
      )
      parameter name: :page, in: :query, type: :integer, example: 1

      produces "application/json"
      response "200", "success response" do
        expected_response_schema = load_spec_schema("search_response")
        schema expected_response_schema

        let(:q) { "awesome post" }
        let(:page) { 1 }

        run_test!
      end
    end
  end
end
