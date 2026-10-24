# frozen_string_literal: true

RSpec.describe FormTemplate::RenderSubmission do
  describe described_class::Contract, type: :model do
    subject(:contract) { described_class.new(form_template_data:) }

    let(:form_template_data) { { id: 1, answers: {} }.to_json }

    it { is_expected.to validate_presence_of(:category_id) }
    it { is_expected.to validate_presence_of(:form_template_data) }

    it "parses the payload into a submission" do
      contract.valid?

      expect(contract.submission.id).to eq(1)
      expect(contract.submission.answers).to eq({})
    end

    context "when the payload is not JSON" do
      let(:form_template_data) { "not json" }

      it { is_expected.to be_invalid }
    end

    context "when the payload is not an object" do
      let(:form_template_data) { "[]" }

      it { is_expected.to be_invalid }
    end

    context "when the payload has no template id" do
      let(:form_template_data) { { answers: {} }.to_json }

      it { is_expected.to be_invalid }
    end

    context "when the answers are not an object" do
      let(:form_template_data) { { id: 1, answers: [] }.to_json }

      it { is_expected.to be_invalid }
    end

    context "when the payload is too large" do
      let(:form_template_data) do
        { id: 1, answers: { text: "x" * FormTemplate::RenderSubmission::MAX_PAYLOAD_SIZE } }.to_json
      end

      it { is_expected.to be_invalid }
    end
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, options:, **dependencies) }

    fab!(:current_user) { Fabricate(:user, trust_level: 2) }
    fab!(:category)
    fab!(:form_template) do
      Fabricate(
        :form_template,
        template: [
          {
            id: "description",
            type: "composer",
            attributes: {
              label: "Details",
            },
            validations: {
              required: true,
            },
          },
          { id: "seats", type: "input", validations: { type: "number" } },
        ].as_json.to_yaml,
      )
    end

    let(:params) { { category_id:, form_template_data: submission.to_json } }
    let(:options) { {} }
    let(:dependencies) { { guardian: current_user.guardian } }
    let(:category_id) { category.id }
    let(:submission) { { id: form_template.id, answers: } }
    let(:answers) { { description: "**Hello**", seats: "1e2" } }

    before do
      SiteSetting.enable_form_templates = true
      category.form_templates << form_template
    end

    context "when the contract is invalid" do
      let(:params) { { category_id:, form_template_data: "not json" } }

      it { is_expected.to fail_a_contract }
    end

    context "when form templates are disabled" do
      before { SiteSetting.enable_form_templates = false }

      it { is_expected.to fail_a_policy(:form_templates_enabled) }
    end

    context "when the category does not exist" do
      let(:category_id) { 0 }

      it { is_expected.to fail_to_find_a_model(:category) }
    end

    context "when the user cannot create topics in the category" do
      fab!(:category) { Fabricate(:private_category, group: Fabricate(:group)) }

      it { is_expected.to fail_a_policy(:can_create_topic_on_category) }
    end

    context "when the template is not attached to the category" do
      fab!(:form_template)

      before { category.form_templates.delete_all }

      it { is_expected.to fail_to_find_a_model(:form_template) }
    end

    context "when the answers do not match the template fields" do
      let(:answers) { { unknown: "value" } }

      it { is_expected.to fail_a_policy(:answers_match_fields) }
    end

    context "when a required answer is missing" do
      let(:answers) { { seats: "2" } }

      it { is_expected.to fail_a_policy(:answers_are_complete) }

      it "names the field in the reason" do
        expect(result["result.policy.answers_are_complete"].reason).to eq(
          I18n.t("form_templates.invalid_answer", field: "Details"),
        )
      end

      context "when incomplete answers are allowed" do
        let(:options) { { allow_incomplete_answers: true } }

        it { is_expected.to run_successfully }

        it "renders the answers that were given" do
          expect(result.raw).to eq("### undefined\n2")
        end
      end
    end

    context "when the output template cannot be rendered" do
      before do
        form_template.update_column(
          :output_template,
          "{% for outer in answers.games %}{% for inner in answers.games %}x{% endfor %}{% endfor %}",
        )
        form_template.update_column(
          :template,
          [{ id: "games", type: "multi-select" }].as_json.to_yaml,
        )
      end

      let(:answers) { { games: Array.new(200, "x") } }

      it { is_expected.to fail_with_exception(Liquid::Error) }
    end

    context "when everything's ok" do
      it { is_expected.to run_successfully }

      it "renders the default output" do
        expect(result.raw).to eq("### Details\n**Hello**\n\n### undefined\n1e2")
      end

      context "with an output template" do
        before { form_template.update!(output_template: "## Session\n{{ answers.description }}") }

        it "renders the configured output" do
          expect(result.raw).to eq("## Session\n**Hello**")
        end
      end
    end
  end
end
