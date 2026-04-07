# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Form::Submit do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:uuid) }
    it { is_expected.to allow_value({}).for(:form_data) }
    it { is_expected.not_to allow_value("string").for(:form_data) }
    it { is_expected.not_to allow_value([]).for(:form_data) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:user)
    let(:dependencies) { { guardian: Guardian.new(user) } }

    fab!(:workflow) do
      Fabricate(
        :discourse_workflows_workflow,
        enabled: true,
        nodes: [
          {
            "id" => "trigger-1",
            "type" => "trigger:form",
            "type_version" => "1.0",
            "name" => "Form Trigger",
            "position" => {
              "x" => 0,
              "y" => 0,
            },
            "position_index" => 0,
            "configuration" => {
              "uuid" => "a1b2c3d4-e5f6-7890-abcd-ef0123456789",
              "form_title" => "Test Form",
              "form_fields" => [
                { "field_label" => "Name", "field_type" => "text", "required" => true },
              ],
              "response_mode" => "on_received",
            },
          },
        ],
        connections: [],
      )
    end

    let(:uuid) { "a1b2c3d4-e5f6-7890-abcd-ef0123456789" }
    let(:form_data) { { "name" => "Test User" } }
    let(:params) { { uuid: uuid, form_data: form_data } }

    before { SiteSetting.discourse_workflows_enabled = true }

    context "when the contract is invalid" do
      let(:uuid) { nil }

      it { is_expected.to fail_a_contract }
    end

    context "when the workflow is not found" do
      let(:uuid) { "00000000-0000-0000-0000-000000000000" }

      it { is_expected.to fail_to_find_a_model(:workflow) }
    end

    context "when the workflow is disabled" do
      before { workflow.update!(enabled: false) }

      it { is_expected.to fail_to_find_a_model(:workflow) }
    end

    context "when everything's ok" do
      it { is_expected.to run_successfully }

      it "creates an execution" do
        expect { result }.to change { DiscourseWorkflows::Execution.count }.by(1)
      end

      it "sets the execution in the context" do
        result
        expect(result[:execution]).to be_a(DiscourseWorkflows::Execution)
      end

      it "computes response metadata" do
        result
        expect(result[:response_metadata]).to include(
          has_downstream_form: false,
          response_mode: "on_received",
        )
      end
    end
  end
end
