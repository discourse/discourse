# frozen_string_literal: true

RSpec.describe DiscourseDataExplorer::Query::Create do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:name) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:acting_user, :admin)
    fab!(:group)

    let(:params) { { name:, description:, sql:, group_ids: } }
    let(:dependencies) { { guardian: acting_user.guardian } }
    let(:name) { "My report" }
    let(:description) { "A useful report" }
    let(:sql) { "SELECT 1 AS one" }
    let(:group_ids) { [group.id] }

    context "when the contract is invalid" do
      let(:name) { "" }

      it { is_expected.to fail_a_contract }
    end

    context "when the acting user is not an admin" do
      fab!(:acting_user, :user)

      it { is_expected.to fail_a_policy(:can_create_query) }
    end

    context "when a requested group doesn't exist" do
      let(:group_ids) { [group.id, -1] }

      it { is_expected.to fail_a_policy(:all_requested_groups_exist) }
    end

    context "when everything's ok" do
      let(:query) { DiscourseDataExplorer::Query.last }

      it { is_expected.to run_successfully }

      it "creates the query" do
        expect { result }.to change { DiscourseDataExplorer::Query.count }.by(1)
        expect(query).to have_attributes(
          name: "My report",
          description: "A useful report",
          sql: "SELECT 1 AS one",
          user_id: acting_user.id,
        )
      end

      it "sets last_run_at to the current time" do
        freeze_time

        result

        expect(query.last_run_at).to eq_time(Time.zone.now)
      end

      it "binds the query to the requested groups" do
        result

        expect(query.groups).to contain_exactly(group)
      end

      context "when the sql is blank" do
        let(:sql) { "" }

        it "defaults the sql to SELECT 1" do
          result

          expect(query.sql).to eq(described_class::DEFAULT_SQL)
        end
      end

      context "when group_ids contains duplicates" do
        let(:group_ids) { [group.id, group.id] }

        it "binds the query to the deduplicated groups" do
          result

          expect(query.groups).to contain_exactly(group)
        end
      end

      context "when group_ids is empty" do
        let(:group_ids) { [] }

        it "binds the query to no groups" do
          result

          expect(query.groups).to be_empty
        end
      end

      context "when group_ids is nil" do
        let(:group_ids) { nil }

        it "binds the query to no groups" do
          result

          expect(query.groups).to be_empty
        end
      end
    end
  end
end
