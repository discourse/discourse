# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Variable::List do
  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:admin)

    let(:params) { {} }
    let(:dependencies) { { guardian: admin.guardian } }

    context "when user cannot manage workflows" do
      fab!(:user)

      let(:dependencies) { { guardian: user.guardian } }

      it { is_expected.to fail_a_policy(:can_manage_workflows) }
    end

    context "when there are no variables" do
      it { is_expected.to run_successfully }

      it "returns an empty collection" do
        expect(result[:variables]).to be_empty
      end

      it "returns zero total rows" do
        expect(result[:total_rows]).to eq(0)
      end

      it "does not return a load more url" do
        expect(result[:load_more_url]).to be_nil
      end
    end

    context "when there are variables" do
      fab!(:variable_a, :discourse_workflows_variable) do
        Fabricate(:discourse_workflows_variable, key: "ALPHA")
      end
      fab!(:variable_b, :discourse_workflows_variable) do
        Fabricate(:discourse_workflows_variable, key: "BRAVO")
      end

      it { is_expected.to run_successfully }

      it "returns variables ordered by id descending" do
        expect(result[:variables].map(&:id)).to eq([variable_b.id, variable_a.id])
      end

      it "returns the total count" do
        expect(result[:total_rows]).to eq(2)
      end
    end

    context "with pagination" do
      let(:params) { { limit: 2 } }

      fab!(:variable_1, :discourse_workflows_variable) do
        Fabricate(:discourse_workflows_variable, key: "FIRST")
      end
      fab!(:variable_2, :discourse_workflows_variable) do
        Fabricate(:discourse_workflows_variable, key: "SECOND")
      end
      fab!(:variable_3, :discourse_workflows_variable) do
        Fabricate(:discourse_workflows_variable, key: "THIRD")
      end

      it "returns only the requested number of variables" do
        expect(result[:variables].size).to eq(2)
      end

      it "returns a load more url with cursor" do
        last_id = result[:variables].last.id
        expect(result[:load_more_url]).to eq(
          "/admin/plugins/discourse-workflows/variables.json?cursor=#{last_id}&limit=2",
        )
      end

      context "when using a cursor" do
        let(:params) { { limit: 2, cursor: variable_3.id } }

        it "returns variables after the cursor" do
          expect(result[:variables].map(&:id)).to eq([variable_2.id, variable_1.id])
        end

        it "does not return a load more url when no more results" do
          expect(result[:load_more_url]).to be_nil
        end
      end
    end
  end
end
