# frozen_string_literal: true

RSpec.describe "User Profile Info Panel" do
  let(:user_page) { PageObjects::Pages::User.new }

  describe "trust level" do
    shared_examples "user profile info panel for trust_level" do |trust_level|
      context "when user has trust level #{trust_level}" do
        fab!(:user) { Fabricate(:user, trust_level: trust_level) }
        before { sign_in(user) }

        it "displays the correct trust level element" do
          user_page.visit(user).expand_info_panel
          expect(user_page).to have_css("dd.trust-level", text: TrustLevel.name(trust_level))
        end
      end
    end

    include_examples "user profile info panel for trust_level", 0
    include_examples "user profile info panel for trust_level", 1
    include_examples "user profile info panel for trust_level", 2
    include_examples "user profile info panel for trust_level", 3
    include_examples "user profile info panel for trust_level", 4
  end
end
