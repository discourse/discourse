# frozen_string_literal: true

# Executable acceptance script for docs/plugins-design.md — a foreign owner (the
# run-stats stand-in plugin, registered for real at boot; see
# lib/discourse_data_explorer/run_stats.rb) attaches to the `queries` resource.
# Proves B (include-gated relationship), D (auto-namespaced filter keys), E1
# (unregistered ⇒ strict 400s), the atomic ownership enforcement claimed in A/B,
# and C's timeline semantics (own timeline frozen at the pin, overrides,
# CORE_PLUGINS riding the core timeline).
RSpec.describe "JSON:API Kit plugins" do
  fab!(:admin)
  fab!(:ran_query) { Fabricate(:query, hidden: false, last_run_at: Time.utc(2026, 7, 1, 10, 0)) }
  fab!(:never_run_query) { Fabricate(:query, hidden: false, last_run_at: nil) }

  let(:current_version) { "2026-07-08" }
  let(:parsed_document) { JSON.parse(response.body) }
  let(:included_attributes) { parsed_document["included"].map { it["attributes"] } }

  before do
    SiteSetting.data_explorer_enabled = true
    freeze_time Time.zone.parse("2026-07-08 12:00")
    sign_in(admin)
  end

  def get_queries(params: {}, version: current_version)
    get "/data-explorer/api/queries",
        params: params,
        headers: {
          "Accept" => "application/vnd.api+json",
          "Api-Version" => version,
        }
  end

  context "when the namespace is included" do
    let(:linkages) { parsed_document["data"].map { it.dig("relationships", "run-stats", "data") } }

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

  describe "the plugin's own timeline" do
    context "when an old-pinned client includes the namespace" do
      before { get_queries(params: { include: "run-stats" }, version: "2026-06-01") }

      it "serves the old attribute name" do
        expect(included_attributes).to contain_exactly(
          { "outdated" => false },
          { "outdated" => true },
        )
      end
    end

    context "when an old-pinned client filters through the old namespaced key" do
      let(:returned_ids) { parsed_document["data"].map { it["id"] } }

      before do
        get_queries(params: { filter: { "run-stats.outdated" => "true" } }, version: "2026-06-01")
      end

      it "returns only the matching queries" do
        expect(returned_ids).to eq([never_run_query.id.to_s])
      end
    end

    context "when an old-pinned client requests a sparse fieldset with the old name" do
      before do
        get_queries(
          params: {
            include: "run-stats",
            fields: {
              "run-stats" => "outdated",
            },
          },
          version: "2026-06-01",
        )
      end

      it "honors the old field name" do
        expect(included_attributes).to contain_exactly(
          { "outdated" => false },
          { "outdated" => true },
        )
      end
    end

    context "when a current-pinned client includes the namespace" do
      before { get_queries(params: { include: "run-stats" }) }

      it "serves the latest attribute name" do
        expect(included_attributes).to contain_exactly({ "stale" => false }, { "stale" => true })
      end
    end

    context "when the pinned date falls between the change and the next core version" do
      before { get_queries(params: { include: "run-stats" }, version: "2026-06-25") }

      it "snaps past the plugin's change to the core timeline" do
        expect(response.headers["Api-Version"]).to eq("2026-06-15")
      end

      it "keeps the plugin frozen at the pin" do
        expect(included_attributes).to contain_exactly(
          { "outdated" => false },
          { "outdated" => true },
        )
      end
    end

    context "with an override unfreezing the plugin on an old base pin" do
      before do
        get_queries(params: { include: "run-stats" }, version: "2026-06-01; run-stats=2026-06-25")
      end

      it "serves the plugin's latest shape" do
        expect(included_attributes).to contain_exactly({ "stale" => false }, { "stale" => true })
      end

      it "keeps the core resources at the base pin" do
        expect(parsed_document["data"].first["attributes"]).to have_key("sql")
      end

      it "echoes each pin snapped against its own timeline" do
        expect(response.headers["Api-Version"]).to eq("2026-05-01; run-stats=2026-06-20")
      end
    end

    context "with an override pinning the plugin older than the base" do
      before do
        get_queries(params: { include: "run-stats" }, version: "2026-07-08; run-stats=2026-06-01")
      end

      it "serves the plugin's old shape" do
        expect(included_attributes).to contain_exactly(
          { "outdated" => false },
          { "outdated" => true },
        )
      end

      it "echoes the override snapped to the initial version" do
        expect(response.headers["Api-Version"]).to eq("2026-07-08; run-stats=2026-05-01")
      end
    end

    context "with an override naming an unknown component" do
      before { get_queries(version: "2026-07-08; nonexistent=2026-07-01") }

      it "rejects the request" do
        expect(response.status).to eq(400)
      end
    end
  end

  context "with the plugin granted core-timeline membership" do
    around do |example|
      DiscourseDataExplorer::JsonApiKit.unregister_plugin("run-stats")
      stub_const(DiscourseDataExplorer::JsonApiKit, :CORE_PLUGINS, ["run-stats"]) do
        DiscourseDataExplorer::RunStats.register!
        example.run
      end
    ensure
      DiscourseDataExplorer::JsonApiKit.unregister_plugin("run-stats")
      DiscourseDataExplorer::RunStats.register!
    end

    context "when the pinned date falls between the change and the next core version" do
      before { get_queries(params: { include: "run-stats" }, version: "2026-06-25") }

      it "snaps to the plugin's change date" do
        expect(response.headers["Api-Version"]).to eq("2026-06-20")
      end

      it "serves the plugin's latest shape" do
        expect(included_attributes).to contain_exactly({ "stale" => false }, { "stale" => true })
      end
    end

    context "when the client is pinned before the change" do
      before { get_queries(params: { include: "run-stats" }, version: "2026-06-15") }

      it "serves the plugin's old shape" do
        expect(included_attributes).to contain_exactly(
          { "outdated" => false },
          { "outdated" => true },
        )
      end
    end

    context "with an override naming the core plugin" do
      before { get_queries(version: "2026-07-08; run-stats=2026-06-01") }

      it "rejects the request" do
        expect(response.status).to eq(400)
      end
    end
  end

  context "without the plugin" do
    around do |example|
      DiscourseDataExplorer::JsonApiKit.unregister_plugin("run-stats")
      example.run
    ensure
      DiscourseDataExplorer::RunStats.register!
    end

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

  # The plugin.rb declaration surface: one `jsonapi` block per plugin,
  # available to every Plugin::Instance (the run-stats registration itself goes
  # through it at boot).
  describe "the plugin.rb `jsonapi` keyword" do
    let(:data_explorer) { Discourse.plugins_by_name["discourse-data-explorer"] }

    around do |example|
      DiscourseDataExplorer::JsonApiKit.unregister_plugin("run-stats")
      example.run
    ensure
      DiscourseDataExplorer::JsonApiKit.unregister_plugin("run-stats")
      DiscourseDataExplorer::RunStats.register!
    end

    it "registers the declarations with the Kit" do
      data_explorer.jsonapi(namespace: "run-stats") do
        register_relationship(:queries, resource: DiscourseDataExplorer::RunStats::StatsResource) do
          nil
        end
      end

      expect(DiscourseDataExplorer::JsonApiKit.plugins.keys).to include("run-stats")
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
        DiscourseDataExplorer::JsonApiKit.register_plugin(namespace: "query-health") do
          register_version_change version_change
        end
      end
    end
    let(:user_stats_resource) do
      Class.new(DiscourseDataExplorer::JsonApiKit::ResourceBase) do
        type :"user-stats"
        attribute :count, :integer
      end
    end
    let(:colliding_registration) do
      resource = user_stats_resource
      -> do
        DiscourseDataExplorer::JsonApiKit.register_plugin(namespace: "user") do
          register_relationship(:queries, resource:) { nil }
        end
      end
    end
    let(:plain_serializer_registration) do
      serializer =
        Class.new do
          include JSONAPI::Serializer
          set_type :"plain-stats"
          attributes :stale
        end
      -> do
        DiscourseDataExplorer::JsonApiKit.register_plugin(namespace: "plain-stats") do
          register_relationship(:queries, resource: serializer) { nil }
        end
      end
    end

    it "rejects a version change targeting a foreign type" do
      expect { foreign_type_registration.call }.to raise_error(
        DiscourseDataExplorer::JsonApiKit::Plugin::OwnershipError,
      )
    end

    it "rejects a namespace colliding with a member name on the attached type" do
      expect { colliding_registration.call }.to raise_error(
        DiscourseDataExplorer::JsonApiKit::Plugin::NamespaceError,
      )
    end

    it "rejects a related resource that is not a Kit resource class" do
      expect { plain_serializer_registration.call }.to raise_error(
        DiscourseDataExplorer::JsonApiKit::Plugin::Error,
        /Kit resource classes/,
      )
    end

    it "rejects a second registration of an already-registered namespace" do
      expect {
        DiscourseDataExplorer::JsonApiKit.register_plugin(namespace: "run-stats") {}
      }.to raise_error(DiscourseDataExplorer::JsonApiKit::Plugin::NamespaceError)
    end
  end
end
