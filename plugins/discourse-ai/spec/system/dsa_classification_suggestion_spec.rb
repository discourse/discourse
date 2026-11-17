# frozen_string_literal: true

RSpec.describe "DSA classification suggestion" do
  fab!(:moderator)
  fab!(:decision_model)
  fab!(:post) { Fabricate(:post, raw: "Buy cheap watches at my shop, best deals online!") }

  fab!(:reviewable) do
    PostActionCreator.create(
      Fabricate(:user, trust_level: TrustLevel[3]),
      post,
      :inappropriate,
    ).reviewable
  end

  let(:review_page) { PageObjects::Pages::Review.new }
  let(:modal) { PageObjects::Modals::DsaModeration.new }
  let(:advertising_rule) do
    {
      ground: "No advertising",
      explanation:
        "You may not send advertisements, chain letters, or other solicitations through the forum, or use the forum to gather addresses or other personal data for commercial mailing lists or databases.",
    }
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

  it "prefills the classification and lets the moderator adjust it before silencing the user" do
    penalty_modal = PageObjects::Modals::PenalizeUser.new("silence")

    DiscourseAi::Decisions.with_canned_answers(
      community_rule: "#{advertising_rule[:ground]}: #{advertising_rule[:explanation]}",
      category:,
    ) do
      review_page.visit_reviewable(reviewable)
      review_page.select_bundled_action(reviewable, "post-agree_and_silence", bundle_index: 1)
      penalty_modal.set_future_date("two_weeks")
      penalty_modal.fill_in_silence_reason("Repeated unsolicited advertising.")
      modal.continue

      expect(modal).to have_selected_rule(advertising_rule[:ground])
      expect(modal).to have_selected_category(category)
      expect(review_page).to have_reviewable_with_pending_status(reviewable)

      expect(modal).to have_field_hint(:community_rule, "Suggested by AI")
      expect(modal).to have_field_hint(:category, "Suggested by AI")
      modal.open_rule_menu
      expect(modal).to have_readable_rule(advertising_rule[:ground])
      modal.close_rule_menu

      modal.select_category("Other violation of terms and conditions")

      expect(modal).to have_no_field_hint(:category)
      expect(modal).to have_field_hint(:community_rule, "Suggested by AI")

      modal.confirm("Silence")

      expect(modal).to be_closed
      expect(review_page).to have_reviewable_with_problem_confirmed_status(reviewable)
    end
  end

  it "labels only the field AI prefilled when there is a partial suggestion" do
    SiteSetting.dsa_community_rules = [advertising_rule].to_json
    DiscourseAi::Decisions.with_canned_answers(category:) do
      review_page.visit_reviewable(reviewable)
      PageObjects::CDP
        .new
        .with_paused_request("**/dsa-classifications/*/suggest") do |request|
          review_page.select_bundled_action(reviewable, "post-agree_and_edit", bundle_index: 1)
          expect(modal).to have_field_hint(:category, "AI is generating")
          expect(modal).to have_no_field_hint(:community_rule)
          expect(modal).to have_disabled_classification_fields
          request.wait
          request.resume
        end

      expect(modal).to have_selected_category(category)
      expect(modal).to have_field_hint(:category, "Suggested by AI")
      expect(modal).to have_no_field_hint(:community_rule)
    end
  end
end
