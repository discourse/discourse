# frozen_string_literal: true

# Executable acceptance script for docs/plugins-design.md — a foreign owner (a fake
# "plugin", namespace `run-stats`) attaches to the `queries` resource. Proves B
# (include-gated relationship), D (auto-namespaced filter keys), E1 (unregistered ⇒
# strict 400s), and the atomic ownership enforcement claimed in A/B. Written AHEAD
# of the extension registry; the "without the extension" examples pin today's
# contract and pass from day one.
RSpec.describe "JSON:API Kit plugin extensions" do
  fab!(:admin)
  fab!(:ran_query) { Fabricate(:query, hidden: false, last_run_at: Time.utc(2026, 7, 1, 10, 0)) }
  fab!(:never_run_query) { Fabricate(:query, hidden: false, last_run_at: nil) }

  let(:current_version) { "2026-07-08" }
  let(:parsed_document) { JSON.parse(response.body) }
  let(:run_stats_class) { Struct.new(:id, :stale) }
  let(:run_stats_serializer) do
    Class.new do
      include JSONAPI::Serializer
      set_type :"run-stats"
      attributes :stale
    end
  end

  before do
    SiteSetting.data_explorer_enabled = true
    freeze_time Time.zone.parse("2026-07-08 12:00")
    sign_in(admin)
  end

  def get_queries(params: {})
    get "/data-explorer/api/queries",
        params: params,
        headers: {
          "Accept" => "application/vnd.api+json",
          "Api-Version" => current_version,
        }
  end

  def register_run_stats_extension
    stats = run_stats_class
    serializer = run_stats_serializer
    DiscourseDataExplorer::JsonApiKit.register_extension(namespace: "run-stats") do
      register_relationship(:queries, serializer:) do |query|
        stats.new(query.id, query.last_run_at.nil?)
      end
      register_filter(:queries, :stale) do |scope, value|
        value == "true" ? scope.where(last_run_at: nil) : scope.where.not(last_run_at: nil)
      end
    end
  end

  context "with the extension registered" do
    before { register_run_stats_extension }

    after { DiscourseDataExplorer::JsonApiKit.unregister_extension("run-stats") }

    context "when the namespace is included" do
      let(:linkages) do
        parsed_document["data"].map { it.dig("relationships", "run-stats", "data") }
      end

      before { get_queries(params: { include: "run-stats" }) }

      it "responds successfully" do
        expect(response.status).to eq(200)
      end

      it "links each query to its plugin resource" do
        expect(linkages).to eq(
          [
            { "id" => ran_query.id.to_s, "type" => "run-stats" },
            { "id" => never_run_query.id.to_s, "type" => "run-stats" },
          ],
        )
      end

      it "serves the plugin resources with their attributes" do
        expect(parsed_document["included"]).to contain_exactly(
          hash_including(
            "type" => "run-stats",
            "id" => ran_query.id.to_s,
            "attributes" => {
              "stale" => false,
            },
          ),
          hash_including(
            "type" => "run-stats",
            "id" => never_run_query.id.to_s,
            "attributes" => {
              "stale" => true,
            },
          ),
        )
      end
    end

    context "without the include" do
      let(:relationship_keys) do
        parsed_document["data"].flat_map { (it["relationships"] || {}).keys }
      end

      before { get_queries }

      it "omits the plugin resources" do
        expect(parsed_document).not_to have_key("included")
      end

      it "omits the relationship linkage" do
        expect(relationship_keys).not_to include("run-stats")
      end
    end

    context "when filtering through the auto-namespaced key" do
      let(:returned_ids) { parsed_document["data"].map { it["id"] } }

      before { get_queries(params: { filter: { "run-stats.stale" => "true" } }) }

      it "returns only the matching queries" do
        expect(returned_ids).to eq([never_run_query.id.to_s])
      end
    end
  end

  context "without the extension" do
    context "when the namespace is included" do
      before { get_queries(params: { include: "run-stats" }) }

      it "rejects the request" do
        expect(response.status).to eq(400)
      end
    end

    context "when filtering through the namespaced key" do
      before { get_queries(params: { filter: { "run-stats.stale" => "true" } }) }

      it "rejects the request" do
        expect(response.status).to eq(400)
      end
    end
  end

  describe "registration enforcement" do
    let(:foreign_type_change) do
      Class.new(DiscourseDataExplorer::JsonApiKit::VersionChange) do
        version "2026-07-08"
        description "Illegal: a plugin change targeting a core-owned type."

        resource :queries do
          renamed_attribute from: :name, to: :title
        end
      end
    end
    let(:foreign_type_registration) do
      version_change = foreign_type_change
      -> do
        DiscourseDataExplorer::JsonApiKit.register_extension(namespace: "run-stats") do
          register_version_change version_change
        end
      end
    end
    let(:colliding_registration) do
      serializer = run_stats_serializer
      -> do
        DiscourseDataExplorer::JsonApiKit.register_extension(namespace: "user") do
          register_relationship(:queries, serializer:) { nil }
        end
      end
    end

    it "rejects a version change targeting a foreign type" do
      expect { foreign_type_registration.call }.to raise_error(
        DiscourseDataExplorer::JsonApiKit::Extension::OwnershipError,
      )
    end

    it "rejects a namespace colliding with a member name on the attached type" do
      expect { colliding_registration.call }.to raise_error(
        DiscourseDataExplorer::JsonApiKit::Extension::NamespaceError,
      )
    end

    context "when the namespace is already registered" do
      before { register_run_stats_extension }

      after { DiscourseDataExplorer::JsonApiKit.unregister_extension("run-stats") }

      it "rejects the second registration" do
        expect { register_run_stats_extension }.to raise_error(
          DiscourseDataExplorer::JsonApiKit::Extension::NamespaceError,
        )
      end
    end
  end
end
