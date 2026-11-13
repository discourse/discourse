# frozen_string_literal: true

RSpec.describe DiscourseDataExplorer::CreateQuery do
  describe described_class::Contract, type: :model do
    subject(:contract) { described_class.new(**params) }

    let(:params) { {} }

    it { is_expected.to validate_presence_of(:name) }

    describe "#query_attributes" do
      subject(:query_attributes) { contract.query_attributes }

      context "when SQL and description are blank" do
        let(:params) { { name: "Recent posts", sql: " \n", description: " " } }

        it "omits blank attributes" do
          expect(query_attributes).to eq(name: "Recent posts")
        end
      end
    end

    describe "#requested_group_ids" do
      subject(:requested_group_ids) { contract.requested_group_ids }

      context "when group IDs are omitted" do
        it { is_expected.to eq([]) }
      end

      context "when group IDs contain duplicates" do
        let(:params) { { group_ids: [3, 7, 3] } }

        it { is_expected.to contain_exactly(3, 7) }
      end
    end
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, guardian: actor.guardian) }

    fab!(:actor, :admin)
    fab!(:group)

    let(:params) do
      {
        name: "Recent posts",
        description: "Posts written this week",
        sql: "SELECT id FROM posts LIMIT 10",
        tags: %w[staff 0012],
        group_ids: [group.id.to_s, group.id.to_s],
      }
    end
    let(:query) { result.query }

    before do
      SiteSetting.data_explorer_enabled = true
      freeze_time(Time.utc(2026, 11, 4, 12))
    end

    context "when the actor is not an admin" do
      fab!(:actor, :user)

      it { is_expected.to fail_a_policy(:can_create_query) }
    end

    context "when data is invalid" do
      let(:params) { super().merge(name: " ") }

      it { is_expected.to fail_a_contract }
    end

    context "when only some requested groups exist" do
      let(:params) { super().merge(group_ids: [group.id, Group.maximum(:id).next]) }

      it { is_expected.to fail_a_policy(:requested_groups_exist) }
    end

    context "when a tag is reserved" do
      let(:params) { super().merge(tags: ["new tag", "Default"]) }

      it { is_expected.to fail_with_exception(ActiveRecord::RecordInvalid) }

      it "rolls back the query and its associations" do
        expect { result }.not_to change {
          [
            DiscourseDataExplorer::Query.count,
            DiscourseDataExplorer::QueryGroup.count,
            DiscourseDataExplorer::QueryTag.count,
            DiscourseDataExplorer::QueryTagMapping.count,
          ]
        }
      end
    end

    context "when everything is valid" do
      it { is_expected.to run_successfully }

      it "assigns the creator" do
        expect(query.user).to eq(actor)
      end

      it "sets the last run time" do
        expect(query.last_run_at).to eq_time(Time.current)
      end

      it "creates the query" do
        expect { result }.to change { DiscourseDataExplorer::Query.count }.by(1)
      end

      it "assigns the query attributes" do
        expect(query).to have_attributes(
          name: params[:name],
          description: params[:description],
          sql: params[:sql],
          groups: contain_exactly(group),
          tags: contain_exactly(have_attributes(name: "0012"), have_attributes(name: "staff")),
        )
      end
    end
  end
end
