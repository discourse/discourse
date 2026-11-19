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

  it "prefills the community rule and category when the moderator opens the classification modal" do
    DiscourseAi::Decisions.with_canned_answers(
      community_rule: "#{advertising_rule[:ground]}: #{advertising_rule[:explanation]}",
      category:,
    ) do
      review_page.visit_reviewable(reviewable)
      review_page.select_bundled_action(reviewable, "post-agree_and_edit", bundle_index: 1)

      expect(modal).to have_selected_rule(advertising_rule[:ground])
      expect(modal).to have_selected_category(category)
    end
  end
end
