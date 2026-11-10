# frozen_string_literal: true

RSpec.describe DiscourseAi::AiModeration::DsaClassification::Questions do
  subject(:questions) { described_class.new(community_rules:) }

  let(:respect_rule) do
    { "id" => "respect-id", "ground" => "Be respectful", "explanation" => "No personal attacks." }
  end
  let(:ads_rule) { { "id" => "ads-id", "ground" => "No advertising", "explanation" => "" } }
  let(:community_rules) { [respect_rule, ads_rule] }
  let(:scams_label) { "Scams and fraud" }

  before { enable_current_plugin }

  def result_with(**answers)
    DiscourseAi::Decisions::Result.new(
      answers:
        answers.map do |name, choice|
          next DiscourseAi::Decisions::Answers::Refusal.new(name: name.to_s) if choice == :refusal

          DiscourseAi::Decisions::Answers::Choice.new(
            name: name.to_s,
            choice:,
            probabilities: {
              choice => 1.0,
            },
            confidence: 1.0,
          )
        end,
    )
  end

  describe "#to_a" do
    it "asks for the community rule and the category" do
      expect(questions.to_a).to contain_exactly(
        a_hash_including(
          name: "community_rule",
          type: "choice",
          choices: ["Be respectful: No personal attacks.", "No advertising"],
        ),
        a_hash_including(
          name: "category",
          type: "choice",
          instructions:
            a_string_including(
              "https://transparency.dsa.ec.europa.eu/page/documentation",
              "Non-compliance with pricing regulations",
              "Scams and/or fraud",
              "Phishing",
              "Other violation of provider's terms and conditions",
              "Be respectful: No personal attacks.",
            ),
          choices: a_collection_including(scams_label, "Other violation of terms and conditions"),
        ),
      )
    end

    it "offers one category choice per DSA category" do
      category_question = questions.to_a.find { |question| question[:name] == "category" }

      expect(category_question[:choices].size).to eq(DsaStatementOfRecord::CATEGORIES.size)
    end

    it "offers English category labels under a non-English locale" do
      TranslationOverride.upsert!(
        "de",
        "dsa_statements.categories.STATEMENT_CATEGORY_SCAMS_AND_FRAUD",
        "Betrug",
      )

      category_question =
        I18n.with_locale(:de) { questions.to_a.find { |question| question[:name] == "category" } }

      expect(category_question[:choices]).to include(scams_label)
      expect(category_question[:choices]).not_to include("Betrug")
    end

    context "with community rules padded by whitespace" do
      let(:community_rules) do
        [
          { "id" => "padded-id", "ground" => "  Be kind  ", "explanation" => nil },
          { "id" => "trailing-id", "ground" => "No spam", "explanation" => "Ever.\n" },
        ]
      end

      it "offers rule labels stripped like decision questions strip them" do
        rule_question = questions.to_a.find { |question| question[:name] == "community_rule" }

        expect(rule_question[:choices]).to eq(["Be kind", "No spam: Ever."])
        expect(DiscourseAi::Decisions::Question.wrap(rule_question).choices).to eq(
          rule_question[:choices],
        )
      end
    end

    context "with a single community rule" do
      let(:community_rules) { [respect_rule] }

      it "only asks for the category" do
        expect(questions.to_a).to contain_exactly(
          a_hash_including(
            name: "category",
            instructions: a_string_including("Be respectful: No personal attacks."),
          ),
        )
      end
    end
  end

  describe "#suggestion_from" do
    it "maps the chosen labels back to their ids" do
      suggestion =
        questions.suggestion_from(
          result_with(community_rule: "No advertising", category: scams_label),
        )

      expect(suggestion).to have_attributes(
        community_rule: "ads-id",
        category: "STATEMENT_CATEGORY_SCAMS_AND_FRAUD",
      )
    end

    it "leaves refused answers blank" do
      suggestion =
        questions.suggestion_from(result_with(community_rule: :refusal, category: :refusal))

      expect(suggestion).to have_attributes(community_rule: nil, category: nil)
    end

    context "with a single community rule" do
      let(:community_rules) { [respect_rule] }

      it "suggests the only rule" do
        suggestion = questions.suggestion_from(result_with(category: scams_label))

        expect(suggestion).to have_attributes(
          community_rule: "respect-id",
          category: "STATEMENT_CATEGORY_SCAMS_AND_FRAUD",
        )
      end
    end
  end
end
