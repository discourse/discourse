# frozen_string_literal: true

RSpec.describe DiscourseDataExplorer::UpdateQuery do
  describe described_class::Contract, type: :model do
    subject(:contract) { described_class.new(params, model:) }

    let(:params) { { name: "Recent posts" } }
    let(:model) { nil }

    it { is_expected.to validate_presence_of(:name) }

    context "when optional attributes are omitted" do
      it { is_expected.to be_valid }
    end

    context "when SQL is provided" do
      let(:params) { super().merge(sql: "SELECT 1") }

      it { is_expected.to allow_value("").for(:sql) }
      it { is_expected.not_to allow_value(nil).for(:sql).with_message(:blank) }
    end

    context "when tags are provided" do
      let(:params) { super().merge(tags: ["Staff"]) }

      it { is_expected.to allow_value([]).for(:tags) }
      it { is_expected.not_to allow_value(nil).for(:tags).with_message(:invalid) }
    end

    context "when the model is a default query" do
      let(:model) do
        Fabricate.build(
          :query,
          id: -1,
          name: "Stored report",
          description: "Stored description",
          sql: "SELECT 17",
        )
      end
      let(:params) { { name: "", description: "Submitted description", sql: nil, tags: ["Staff"] } }

      it { is_expected.to be_valid }
      it { is_expected.not_to allow_value(nil).for(:tags).with_message(:invalid) }

      it "restores the stored definition" do
        expect { contract.valid? }.to change { contract.query_attributes }.to(
          name: "Stored report",
          description: "Stored description",
          sql: "SELECT 17",
        )
      end
    end

    describe "#requested_group_ids" do
      subject(:requested_group_ids) { contract.requested_group_ids }

      context "when group IDs are omitted" do
        it { is_expected.to be_empty }
      end

      context "when group IDs contain duplicates" do
        let(:params) { { group_ids: [3, 7, 3] } }

        it { is_expected.to contain_exactly(3, 7) }
      end
    end
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:actor, :admin)
    fab!(:query)
    fab!(:group)

    let(:id) { query.id.to_s }
    let(:params) do
      {
        id:,
        name: "Updated report",
        description: "Updated description",
        sql: "SELECT 42",
        group_ids: [group.id.to_s, group.id.to_s],
        tags: [" Custom ", " Staff ", "STAFF", "0012"],
      }
    end
    let(:options) { {} }
    let(:dependencies) { { guardian: actor.guardian, options: } }
    let(:cache) { DiscourseDataExplorer::QueryResultCache }

    before { SiteSetting.data_explorer_enabled = true }

    context "when the actor is not an admin" do
      fab!(:actor, :moderator)

      it { is_expected.to fail_a_policy(:can_update_query) }
    end

    context "when the query does not exist" do
      let(:id) { (DiscourseDataExplorer::Query.maximum(:id) || 0) + 1 }

      it { is_expected.to fail_to_find_a_model(:query) }
    end

    context "when the query is hidden" do
      let(:params) { super().merge(hidden: false, restore_hidden: true) }

      before { query.update!(hidden: true) }

      it { is_expected.to fail_to_find_a_model(:query) }
    end

    context "when data is invalid" do
      let(:params) { super().merge(name: " ") }

      it { is_expected.to fail_a_contract }
    end

    context "when a requested group does not exist" do
      let(:params) { super().merge(group_ids: [group.id, Group.maximum(:id).next]) }

      before { query.groups = [group] }

      it { is_expected.to fail_a_policy(:requested_groups_exist) }

      it "keeps the query name" do
        expect { result }.not_to change { query.reload.name }
      end

      it "keeps the group access" do
        expect { result }.not_to change { query.reload.group_ids }
      end
    end

    context "when a tag is reserved" do
      let(:params) { super().merge(tags: ["default"]) }

      before { cache.write(query.id, actor, {}, "rows" => [[1]]) }

      it { is_expected.to fail_with_exception(ActiveRecord::RecordInvalid) }

      it "rolls back the query and its associations" do
        expect { result }.not_to change { [query.reload.sql, query.group_ids, query.tags.to_a] }
      end

      it "preserves cached results" do
        expect { result }.not_to change { cache.read(query.id, actor, {}) }
      end
    end

    context "when everything is valid" do
      fab!(:previous_group, :group)

      before do
        query.groups = [previous_group]
        DiscourseDataExplorer::QueryTag.sync!(query:, names: ["old"])
        cache.write(query.id, actor, {}, "rows" => [[1]])
      end

      it { is_expected.to run_successfully }

      it "updates the query attributes" do
        expect { result }.to change { query.reload.slice(:name, :description, :sql) }.to(
          "name" => params[:name],
          "description" => params[:description],
          "sql" => params[:sql],
        )
      end

      it "replaces the group access" do
        expect { result }.to change { query.reload.groups.to_a }.to([group])
      end

      it "stores the normalized additional tags" do
        expect { result }.to change { query.reload.tags.pluck(:name) }.to(
          contain_exactly("0012", "staff"),
        )
      end

      it "invalidates cached results" do
        expect { result }.to change { cache.read(query.id, actor, {}) }.to(nil)
      end

      context "when only a name is supplied" do
        let(:params) { { id:, name: "Renamed report", user_id: actor.id, hidden: true } }

        it { is_expected.to run_successfully }

        it "renames the target query" do
          expect { result }.to change { query.reload.name }.to("Renamed report")
        end

        it "keeps the other attributes" do
          expect { result }.not_to change { query.reload.attributes.except("name", "updated_at") }
        end

        it "keeps group access and tags" do
          expect { result }.not_to change { [query.reload.group_ids, query.tags.pluck(:name)] }
        end

        it "preserves cached results" do
          expect { result }.not_to change { cache.read(query.id, actor, {}) }
        end
      end

      context "when description, groups, and tags are cleared without changing SQL" do
        let(:params) { { id:, description: nil, group_ids: [], tags: [], sql: query.sql } }

        it { is_expected.to run_successfully }

        it "clears the description" do
          expect { result }.to change { query.reload.description }.to(nil)
        end

        it "clears group access" do
          expect { result }.to change { query.reload.groups.to_a }.to([])
        end

        it "clears additional tags" do
          expect { result }.to change { query.reload.tags.to_a }.to([])
        end

        it "preserves cached results" do
          expect { result }.not_to change { cache.read(query.id, actor, {}) }
        end
      end

      context "when the query is a persisted default" do
        fab!(:query) { Fabricate(:query, id: -1, sql: "SELECT 42") }

        let(:params) { { id:, sql: "SELECT 99" } }

        it { is_expected.to run_successfully }

        it "preserves cached results" do
          expect { result }.not_to change { cache.read(query.id, actor, {}) }
        end
      end

      context "when the query is hidden and restore_hidden is enabled" do
        let(:options) { { restore_hidden: true } }

        before { query.update!(hidden: true) }

        it { is_expected.to run_successfully }

        it "restores the query" do
          expect { result }.to change { query.reload.hidden }.to(false)
        end
      end
    end
  end
end
