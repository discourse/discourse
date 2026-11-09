# frozen_string_literal: true

RSpec.describe DiscourseDataExplorer::Adapters::CachedResults do
  subject(:adapter) { described_class.new(resource) }

  fab!(:admin)
  fab!(:queries) do
    [5, 10].map do |limit|
      Fabricate(
        :query,
        user: admin,
        sql: "-- [params]\n-- int :limit = #{limit}\n\nSELECT :limit AS value",
      )
    end
  end

  let(:guardian) { admin.guardian }
  let(:resource) { resource_class.new(guardian:) }
  let(:resource_class) do
    Class
      .new(DiscourseDataExplorer::CachedResultResource) do
        model DiscourseDataExplorer::CachedResult
        type :cached_results
      end
      .tap { it.scope(&scope_definition) }
  end
  let(:scope_definition) { ->(_guardian) { scope } }
  let(:scope) { described_class::Selection.new(queries:, params: {}) }
  let(:restricted_scope) { scope.with(queries: [queries.last]) }
  let(:empty_scope) { scope.with(queries: []) }
  let(:available_records) do
    queries.map { DiscourseDataExplorer::QueryRunner.cached_entry(it, nil, current_user: admin) }
  end
  let(:filter_name) { "params" }
  let(:missing_id) do
    DiscourseDataExplorer::QueryResultCache::Key.for(queries.last.id, admin, { "limit" => "99" }).id
  end
  let(:suppressed_categories) { false }

  before do
    SiteSetting.data_explorer_enabled = true
    SiteSetting.suppress_secured_categories_from_admin = suppressed_categories
    queries.each { DiscourseDataExplorer::QueryRunner.run(it, nil, current_user: admin) }
  end

  after { queries.each { DiscourseDataExplorer::QueryRunner.invalidate(it.id) } }

  it_behaves_like "a resource adapter" do
    let(:filter_value) { { "limit" => "10" }.to_json }
  end

  describe "#record_for" do
    subject(:cached_result) { adapter.record_for(id) }

    let(:id) { identity.id }
    let(:identity) do
      DiscourseDataExplorer::QueryResultCache::Key.for(queries.last.id, admin, { "limit" => "10" })
    end

    context "when the query is hidden" do
      before { queries.last.update!(hidden: true) }

      it "raises a missing record error" do
        expect { cached_result }.to raise_error(JsonApiKit::NotFound)
      end
    end

    context "when the resource scope excludes the query" do
      let(:scope) { super().with(queries: [queries.first]) }

      it "raises a missing record error" do
        expect { cached_result }.to raise_error(JsonApiKit::NotFound)
      end
    end

    context "when the identifier is malformed" do
      let(:id) { "not-an-id" }

      it "raises a missing record error" do
        expect { cached_result }.to raise_error(JsonApiKit::NotFound)
      end
    end

    context "when the query stops supporting cached results" do
      before do
        queries.last.update!(
          sql: "-- [params]\n-- current_user_id :viewer\n\nSELECT :viewer AS value",
        )
      end

      it "raises a missing record error" do
        expect { cached_result }.to raise_error(JsonApiKit::NotFound)
      end
    end

    context "when the cache entry expires" do
      before { Discourse.redis.expire(identity.to_s, 0) }

      it "raises a missing record error" do
        expect { cached_result }.to raise_error(JsonApiKit::NotFound)
      end
    end

    context "when admins have separate visibility scopes" do
      fab!(:another_admin, :admin)

      let(:guardian) { another_admin.guardian }
      let(:suppressed_categories) { true }

      it "raises a missing record error" do
        expect { cached_result }.to raise_error(JsonApiKit::NotFound)
      end
    end
  end
end
