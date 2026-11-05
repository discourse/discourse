# frozen_string_literal: true

RSpec.describe DiscourseDataExplorer::CreateQuery do
  describe described_class::Contract, type: :model do
    subject(:contract) { described_class.new }

    it { is_expected.to validate_presence_of(:name) }
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
        tags: [" Staff ", "0012", "staff", "custom"],
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

      it "refuses creation", :aggregate_failures do
        expect { result }.not_to change { DiscourseDataExplorer::Query.count }
        expect(result).to fail_a_policy(:can_create_query)
      end
    end

    context "when the name is blank" do
      let(:params) { super().merge(name: " ") }

      it { is_expected.to fail_a_contract }
    end

    context "when a group does not exist" do
      let(:params) { super().merge(group_ids: [Group.maximum(:id).next]) }

      it "refuses creation", :aggregate_failures do
        expect { result }.not_to change { DiscourseDataExplorer::Query.count }
        expect(result).to fail_to_find_a_model(:groups)
      end
    end

    context "when a tag is reserved" do
      let(:params) { super().merge(tags: ["new tag", "Default"]) }

      it "rolls back the query and its associations", :aggregate_failures do
        expect { result }.not_to change {
          [
            DiscourseDataExplorer::Query.count,
            DiscourseDataExplorer::QueryGroup.count,
            DiscourseDataExplorer::QueryTag.count,
            DiscourseDataExplorer::QueryTagMapping.count,
          ]
        }
        expect(result).to fail_with_exception(ActiveRecord::RecordInvalid)
      end
    end

    context "when only the name is supplied" do
      let(:params) { { name: "Name only" } }

      it "uses the creation defaults", :aggregate_failures do
        expect(result).to run_successfully
        expect(query).to have_attributes(sql: "SELECT 1", description: nil)
        expect(query.groups).to be_empty
        expect(query.tag_names).to contain_exactly("custom")
      end
    end

    context "when SQL and description are blank" do
      let(:params) { super().merge(sql: " \n", description: " ") }

      it "uses the creation defaults", :aggregate_failures do
        expect(result).to run_successfully
        expect(query).to have_attributes(sql: "SELECT 1", description: nil)
      end
    end

    context "when the caller supplies server-owned attributes" do
      fab!(:other_user, :user)

      let(:params) { super().merge(user_id: other_user.id, hidden: true, last_run_at: 1.day.ago) }

      it "uses the server values", :aggregate_failures do
        expect(result).to run_successfully
        expect(query).to have_attributes(
          user_id: actor.id,
          hidden: false,
          last_run_at: Time.current,
        )
      end
    end

    it "creates the query", :aggregate_failures do
      expect { result }.to change { DiscourseDataExplorer::Query.count }.by(1)
      expect(result).to run_successfully
      expect(query).to have_attributes(
        name: params[:name],
        description: params[:description],
        sql: params[:sql],
        user_id: actor.id,
        last_run_at: Time.current,
        hidden: false,
      )
      expect(query.groups).to contain_exactly(group)
      expect(query.tag_names).to contain_exactly("custom", "0012", "staff")
    end
  end
end
