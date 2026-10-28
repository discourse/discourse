# frozen_string_literal: true

RSpec.describe CategoriesController do
  fixture =
    JSON.parse(
      File.read(Rails.root.join("frontend/discourse/tests/fixtures/category-search-parity.json")),
    )

  fab!(:user)
  fab!(:group) { Fabricate(:group, users: [user]) }
  fab!(:search_categories) do
    records = {}
    fixture
      .fetch("categories")
      .each do |row|
        records[row.fetch("symbol")] = if row.fetch("symbol") == "uncategorized"
          Category.find(SiteSetting.uncategorized_category_id)
        else
          permission = { "reply" => :create_post, "readonly" => :readonly }.fetch(
            row.fetch("access"),
            :full,
          )
          permission_group =
            case row.fetch("access")
            when "hidden"
              Group[:staff].name
            when "group"
              group.name
            else
              Group[:everyone].name
            end
          Fabricate(
            :category,
            user: user,
            name: row.fetch("name"),
            permissions: {
              permission_group => CategoryGroup.permission_types[permission],
            },
          )
        end
      end

    # These relationships deliberately include public children of restricted/reply-only parents.
    # Attach them after creation so permission compatibility validation cannot change the fixture.
    fixture
      .fetch("categories")
      .each do |row|
        records.fetch(row.fetch("symbol")).update_columns(
          name: row.fetch("name"),
          parent_category_id: records[row["parent"]]&.id,
          topic_count: row.fetch("topic_count"),
          position: row.fetch("position"),
        )
      end
    records
  end

  def search_params(params)
    params.deep_dup.tap do |result|
      %w[parent_category_id prioritized_category_id].each do |key|
        result[key] = search_categories.fetch(result[key]).id if result[key].is_a?(String)
      end
      %w[select_category_ids reject_category_ids].each do |key|
        next unless result.key?(key)
        if result[key].empty?
          result.delete(key)
        else
          result[key] = result[key].map { |symbol| search_categories.fetch(symbol).id }
        end
      end
    end
  end

  def expected_ids(symbols)
    symbols.map { |symbol| search_categories.fetch(symbol).id }
  end

  def expected_family_keys(keys)
    keys.to_h do |symbol, family|
      [search_categories.fetch(symbol).id.to_s, family && search_categories.fetch(family).id]
    end
  end

  describe "#search" do
    before do
      SiteSetting.max_category_nesting = 3
      SiteSetting.allow_uncategorized_topics = false
      sign_in(user)
    end

    fixture
      .fetch("cases")
      .each do |search_case|
        it "matches the shared search fixture: #{search_case.fetch("name")}" do
          search_case
            .fetch("settings", {})
            .each { |name, value| SiteSetting.public_send("#{name}=", value) }
          post "/categories/search.json", params: search_params(search_case.fetch("params"))

          expect(response.status).to eq(200)
          body = response.parsed_body
          expected = search_case.fetch("expected")
          aggregate_failures do
            expect(body.fetch("categories").map { |category| category.fetch("id") }).to eq(
              expected_ids(expected.fetch("categories")),
            )
            expect(body.fetch("categories_count")).to eq(expected.fetch("count"))
            if expected.key?("family_keys")
              expect(body["family_keys"]).to eq(expected_family_keys(expected.fetch("family_keys")))
            else
              expect(body).not_to have_key("family_keys")
            end
            if search_case.fetch("params")["include_ancestors"]
              expect(
                body.fetch("ancestors").map { |category| category.fetch("id") },
              ).to contain_exactly(*expected_ids(expected.fetch("ancestors")))
            else
              expect(body).not_to have_key("ancestors")
            end
          end
        end
      end

    it "walks grouped pages with consecutive families" do
      expected =
        fixture.fetch("cases").find { |search_case| search_case.fetch("name") == "grouped full" }
      params = search_params(expected.fetch("params"))
      post "/categories/search.json", params: params
      expect(response.status).to eq(200)
      aggregate_failures do
        full_ids = response.parsed_body.fetch("categories").map { |category| category.fetch("id") }
        expect(full_ids).to eq(expected_ids(expected.fetch("expected").fetch("categories")))

        walked_ids =
          (1..expected.fetch("expected").fetch("count")).flat_map do |page|
            post "/categories/search.json", params: params.merge("limit" => 1, "page" => page)
            expect(response.status).to eq(200)
            expect(response.parsed_body.fetch("categories_count")).to eq(15)
            response.parsed_body.fetch("categories").map { |category| category.fetch("id") }
          end
        expect(walked_ids).to eq(full_ids)
        expected_family_keys(expected.fetch("expected").fetch("family_keys"))
          .group_by { |_id, family| family }
          .each do |family, members|
            next if family.nil?
            indices = members.map { |id, _key| walked_ids.index(id.to_i) }.sort
            expect(indices).to eq((indices.first..indices.last).to_a)
          end
      end
    end

    it "puts the key category before its better ranked leaf" do
      post "/categories/search.json",
           params: {
             term: "ember",
             group_families: true,
             prioritized_category_id: search_categories.fetch("leaf").id,
             limit: 25,
           }
      expect(response.status).to eq(200)
      ids = response.parsed_body.fetch("categories").map { |category| category.fetch("id") }
      %w[root branch solo].each do |symbol|
        family_id = search_categories.fetch(symbol).id
        family_keys = response.parsed_body.fetch("family_keys")
        members = ids.select { |id| family_keys.fetch(id.to_s) == family_id }
        expect(members.first).to eq(family_id)
      end
    end

    it "returns exactly the paged family keys including nulls" do
      post "/categories/search.json",
           params: {
             term: "ember",
             group_families: true,
             limit: 3,
             page: 3,
           }
      expect(response.status).to eq(200)
      ids = response.parsed_body.fetch("categories").map { |category| category.fetch("id") }
      keys = response.parsed_body.fetch("family_keys")
      expect(ids).to eq(expected_ids(%w[percent percent_decoy branch]))
      expect(keys.keys).to contain_exactly(*ids.map(&:to_s))
      expect(ids.map { |id| keys.fetch(id.to_s) }).to eq(
        [nil, nil, search_categories.fetch("branch").id],
      )
    end

    it "matches literal wildcards and preserves the plain request ranking" do
      aggregate_failures do
        fixture
          .fetch("cases")
          .select do |search_case|
            ["literal underscore", "literal percent", "base ranking"].include?(
              search_case.fetch("name"),
            )
          end
          .each do |search_case|
            post "/categories/search.json", params: search_params(search_case.fetch("params"))
            expect(response.status).to eq(200)
            expect(
              response.parsed_body.fetch("categories").map { |category| category.fetch("id") },
            ).to eq(expected_ids(search_case.fetch("expected").fetch("categories")))
            expect(response.parsed_body).not_to have_key("family_keys")
          end
      end
    end

    it "matches normalized fullwidth percent literally" do
      post "/categories/search.json", params: { term: "％", limit: 25 }

      expect(response.status).to eq(200)
      body = response.parsed_body
      aggregate_failures do
        expect(body.fetch("categories").map { |category| category.fetch("id") }).to eq(
          expected_ids(["percent"]),
        )
        expect(body.fetch("categories_count")).to eq(1)
      end
    end

    it "matches normalized fullwidth underscore literally" do
      post "/categories/search.json", params: { term: "＿", limit: 25 }

      expect(response.status).to eq(200)
      body = response.parsed_body
      aggregate_failures do
        expect(body.fetch("categories").map { |category| category.fetch("id") }).to eq(
          expected_ids(["underscore"]),
        )
        expect(body.fetch("categories_count")).to eq(1)
      end
    end

    it "defaults the server limit to 25" do
      search_case =
        fixture.fetch("cases").find { |candidate| candidate.fetch("name") == "limit upper clamp" }
      post "/categories/search.json",
           params: search_params(search_case.fetch("params").except("limit"))
      expect(response.status).to eq(200)
      expect(
        response.parsed_body.fetch("categories").map { |category| category.fetch("id") },
      ).to eq(expected_ids(search_case.fetch("expected").fetch("categories")))
      expect(response.parsed_body.fetch("categories_count")).to eq(26)
    end

    it "allows staff to post in uncategorized when disabled" do
      sign_in(Fabricate(:moderator))
      post "/categories/search.json",
           params: {
             term: "",
             only_postable: true,
             select_category_ids: expected_ids(["uncategorized"]),
             limit: 1,
           }
      expect(response.status).to eq(200)
      expect(
        response.parsed_body.fetch("categories").map { |category| category.fetch("id") },
      ).to eq(expected_ids(["uncategorized"]))
      expect(response.parsed_body.fetch("categories_count")).to eq(1)
    end
  end
end
