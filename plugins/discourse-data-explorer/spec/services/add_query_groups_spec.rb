# frozen_string_literal: true

RSpec.describe DiscourseDataExplorer::AddQueryGroups do
  describe described_class::Contract, type: :model do
    subject(:contract) { described_class.new(params) }

    let(:params) { {} }

    it { is_expected.to allow_value([]).for(:group_ids) }
    it { is_expected.not_to allow_value(nil).for(:group_ids).with_message(:blank) }

    describe "#requested_group_ids" do
      subject(:requested_group_ids) { contract.requested_group_ids }

      context "when group IDs contain duplicates" do
        let(:params) { { group_ids: [3, 7, 3] } }

        it { is_expected.to contain_exactly(3, 7) }
      end
    end
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, guardian: actor.guardian) }

    fab!(:actor, :admin)
    fab!(:query)
    fab!(:existing_group, :group)
    fab!(:added_group, :group)

    let(:id) { query.id.to_s }
    let(:group_ids) { [added_group.id.to_s, added_group.id.to_s] }
    let(:params) { { id:, group_ids: } }
    let!(:existing_membership) { Fabricate(:query_group, query:, group: existing_group) }

    before { SiteSetting.data_explorer_enabled = true }

    context "when the actor is not an admin" do
      fab!(:actor, :moderator)

      it { is_expected.to fail_a_policy(:can_add_query_groups) }
    end

    context "when the query does not exist" do
      let(:id) { (DiscourseDataExplorer::Query.maximum(:id) || 0) + 1 }

      it { is_expected.to fail_to_find_a_model(:query) }
    end

    context "when the query is hidden" do
      before { query.update!(hidden: true) }

      it { is_expected.to fail_to_find_a_model(:query) }
    end

    context "when the query is an unpersisted default" do
      let(:id) { "-1" }

      it { is_expected.to fail_to_find_a_model(:query) }

      it "does not persist the default query" do
        expect { result }.not_to change { DiscourseDataExplorer::Query.exists?(id: -1) }
      end
    end

    context "when group IDs are missing" do
      let(:params) { { id: } }

      it { is_expected.to fail_a_contract }
    end

    context "when a requested group does not exist" do
      let(:group_ids) { [added_group.id.to_s, Group.maximum(:id).next.to_s] }

      it { is_expected.to fail_a_policy(:requested_groups_exist) }

      it "keeps the existing group access" do
        expect { result }.not_to change { query.reload.group_ids }
      end
    end

    context "when everything is valid" do
      it { is_expected.to run_successfully }

      it "adds the requested group while keeping existing groups" do
        expect { result }.to change { query.reload.group_ids }.to(
          contain_exactly(existing_group.id, added_group.id),
        )
      end

      it "preserves the existing membership record" do
        expect { result }.not_to change {
          DiscourseDataExplorer::QueryGroup.find_by(query:, group: existing_group)&.id
        }.from(existing_membership.id)
      end

      context "when a requested group is already attached" do
        let(:group_ids) { [existing_group.id.to_s, added_group.id.to_s] }

        it { is_expected.to run_successfully }

        it "adds only the missing group" do
          expect { result }.to change { query.reload.group_ids }.to(
            contain_exactly(existing_group.id, added_group.id),
          )
        end

        it "preserves the existing membership record" do
          expect { result }.not_to change {
            DiscourseDataExplorer::QueryGroup.find_by(query:, group: existing_group)&.id
          }.from(existing_membership.id)
        end
      end

      context "when group IDs are empty" do
        let(:group_ids) { [] }

        it { is_expected.to run_successfully }

        it "keeps the existing group access" do
          expect { result }.not_to change { query.reload.group_ids }
        end
      end

      context "when the query is a persisted default" do
        fab!(:query) { Fabricate(:query, id: -1, sql: "SELECT 42") }

        it { is_expected.to run_successfully }

        it "adds the requested group" do
          expect { result }.to change { query.reload.group_ids }.to(
            contain_exactly(existing_group.id, added_group.id),
          )
        end
      end
    end
  end
end
