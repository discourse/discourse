# frozen_string_literal: true

RSpec.describe "User Profile Info Panel", system: true do
  let(:user_page) { PageObjects::Pages::User.new }

  describe "trust level" do
    TrustLevel.levels.values.each do |trust_level|
      context "when user has trust level #{trust_level}" do
        fab!(:user) { Fabricate(:user, trust_level: trust_level) }
        before { sign_in(user) }

        it "displays the correct trust level element" do
          user_page.visit(user).expand_info_panel
          expect(user_page).to have_css("dd.trust-level", text: TrustLevel.name(trust_level))
        end
      end
    end
  end
end
