# frozen_string_literal: true

RSpec.describe "DSA classification suggestion" do
  fab!(:moderator)
  fab!(:decision_model)
  fab!(:post) { Fabricate(:post, raw: "Buy cheap watches at my shop, best deals online!") }

  let(:review_page) { PageObjects::Pages::Review.new }
  let(:modal) { PageObjects::Modals::DsaModeration.new }
  let(:suggestion) { PageObjects::Components::AiDsaClassificationSuggestion.new }
  let(:advertising_rule) do
    { ground: "No advertising", explanation: "Unsolicited advertising is not allowed." }
  end
  let(:category) { "Scams and fraud" }

  before do
    enable_current_plugin
    enable_dsa_reporting(
      community_rules: [
        { ground: "Be respectful", explanation: "Personal attacks are not allowed." },
        advertising_rule,
      ],
    )
    SiteSetting.reviewable_claiming = "disabled"
    SiteSetting.ai_dsa_classification_decision_model = decision_model.id
    sign_in(moderator)
  end

  it "lets the moderator review the suggested classification before confirming" do
    reviewable =
      PostActionCreator.create(
        Fabricate(:user, trust_level: TrustLevel[3]),
        post,
        :inappropriate,
      ).reviewable

    DiscourseAi::Decisions.with_canned_answers(
      community_rule: "#{advertising_rule[:ground]}: #{advertising_rule[:explanation]}",
      category:,
    ) do
      review_page.visit_reviewable(reviewable)
      review_page.select_bundled_action(reviewable, "post-agree_and_hide", bundle_index: 1)

      expect(modal).to have_classification

      suggestion.suggest

      expect(suggestion).to have_message("Review the suggested classification before you confirm")
      expect(modal).to have_selected_rule(advertising_rule[:ground])
      expect(modal).to have_selected_category(category)
      expect(review_page).to have_reviewable_with_pending_status(reviewable)

      modal.confirm("Save classification")

      expect(modal).to be_closed
      expect(review_page).to have_reviewable_with_approved_status(reviewable)
    end
  end
end
