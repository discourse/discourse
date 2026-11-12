# frozen_string_literal: true

RSpec.describe DiscourseDataExplorer::DefaultQuerySync do
  fab!(:admin)
  fab!(:group)
  fab!(:custom_query, :query)

  let(:definition) do
    { "id" => -1, "name" => "Default query", "description" => "A report", "sql" => "SELECT 1" }
  end
  let(:query) { DiscourseDataExplorer::Query.find_by(id: -1) }
  let(:cache) { DiscourseDataExplorer::QueryResultCache }

  describe ".execute" do
    subject(:sync) { described_class.execute }

    let(:other_definition) { definition.merge("id" => -2, "name" => "Other default") }
    let(:definitions) { { "-1" => definition, "-2" => other_definition } }

    before { allow(DiscourseDataExplorer::Queries).to receive(:default).and_return(definitions) }

    it "synchronizes each default query" do
      sync

      expect(
        DiscourseDataExplorer::Query.where("id < 0").map { it.attributes.slice(*definition.keys) },
      ).to contain_exactly(definition, other_definition)
    end

    context "when database seeds run" do
      subject(:sync) do
        silence_stdout do
          SeedFu.seed(DiscoursePluginRegistry.seed_paths, %r{discourse-data-explorer/db/fixtures/})
        end
      end

      before { allow(Rails.env).to receive(:test?).and_return(false) }

      it "synchronizes default queries" do
        expect { sync }.to change { DiscourseDataExplorer::Query.exists?(id: -1) }.to(true)
      end
    end

    context "when defaults are already synchronized" do
      before do
        described_class.execute
        freeze_time 1.day.from_now
      end

      it "leaves the records unchanged" do
        expect { sync }.not_to change { DiscourseDataExplorer::Query.order(:id).map(&:attributes) }
      end
    end

    context "when a new default query is added" do
      let(:new_definition) { definition.merge("id" => -3, "name" => "New default") }

      before do
        described_class.execute
        allow(DiscourseDataExplorer::Queries).to receive(:default).and_return(
          definitions.merge("-3" => new_definition),
        )
      end

      it "persists the new definition" do
        expect { sync }.to change { DiscourseDataExplorer::Query.find_by(id: -3)&.attributes }.to(
          a_hash_including(new_definition),
        )
      end
    end
  end

  describe "#execute" do
    subject(:sync) { described_class.new(definition).execute }

    it "persists the default definition" do
      sync

      expect(query).to have_attributes(
        definition.merge("user_id" => Discourse::SYSTEM_USER_ID, "last_run_at" => nil),
      )
    end

    it "preserves custom queries" do
      expect { sync }.not_to change { custom_query.reload.attributes }
    end

    context "when a default query already exists" do
      let!(:existing_query) do
        Fabricate(
          :query,
          id: -1,
          sql: "SELECT 0",
          hidden: true,
          last_run_at: 2.days.ago,
          created_at: 1.year.ago,
        )
      end
      let(:local_state) { %w[hidden last_run_at created_at] }

      before do
        existing_query.groups = [group]
        DiscourseDataExplorer::QueryTag.sync!(query: existing_query, names: ["staff"])
        cache.write(existing_query.id, admin, {}, "rows" => [[0]])
      end

      it "refreshes the shipped definition" do
        expect { sync }.to change { existing_query.reload.attributes.slice(*definition.keys) }.to(
          definition,
        )
      end

      it "preserves local query state" do
        expect { sync }.not_to change { existing_query.reload.attributes.slice(*local_state) }
      end

      it "preserves group access" do
        expect { sync }.not_to change { existing_query.reload.group_ids }
      end

      it "preserves local tags" do
        expect { sync }.not_to change { existing_query.reload.tags.pluck(:name) }
      end

      it "invalidates cached results from the previous SQL" do
        expect { sync }.to change { cache.read(existing_query.id, admin, {}) }.to(nil)
      end

      context "when the SQL is unchanged" do
        let(:definition) { super().merge("sql" => "SELECT 0") }

        it "preserves cached results" do
          expect { sync }.not_to change { cache.read(existing_query.id, admin, {}) }
        end
      end

      context "when the definition is invalid" do
        let(:definition) { super().merge("name" => nil) }

        it "preserves the stored definition", :aggregate_failures do
          expect { sync }.to raise_error(ActiveRecord::RecordInvalid)
          expect(existing_query.reload.sql).to eq("SELECT 0")
        end

        it "preserves cached results", :aggregate_failures do
          expect { sync }.to raise_error(ActiveRecord::RecordInvalid)
          expect(cache.read(existing_query.id, admin, {})).to include("rows" => [[0]])
        end
      end

      context "when synchronization rolls back" do
        subject(:sync) do
          DiscourseDataExplorer::Query.transaction do
            described_class.new(definition).execute
            raise ActiveRecord::Rollback
          end
        end

        it "preserves the definition and cached results", :aggregate_failures do
          expect { sync }.not_to change { cache.read(existing_query.id, admin, {}) }
          expect(existing_query.reload.sql).to eq("SELECT 0")
        end
      end
    end
  end
end
