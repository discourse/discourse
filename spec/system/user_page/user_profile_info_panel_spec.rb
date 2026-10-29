# frozen_string_literal: true

RSpec.describe "User Profile Info Panel" do
  let(:user_page) { PageObjects::Pages::User.new }

  describe "trust level" do
    context "when user has trust level 0" do
      fab!(:user) { Fabricate(:user, trust_level: 0) }
      before { sign_in(user) }

      it "displays the correct trust level element" do
        user_page.visit(user).expand_info_panel
        expect(user_page).to have_css("dd.trust-level", text: TrustLevel.name(0))
      end
    end

    context "when user has trust level 1" do
      fab!(:user) { Fabricate(:user, trust_level: 1) }
      before { sign_in(user) }

      it "displays the correct trust level element" do
        user_page.visit(user).expand_info_panel
        expect(user_page).to have_css("dd.trust-level", text: TrustLevel.name(1))
      end
    end

    context "when user has trust level 2" do
      fab!(:user) { Fabricate(:user, trust_level: 2) }
      before { sign_in(user) }

      it "displays the correct trust level element" do
        user_page.visit(user).expand_info_panel
        expect(user_page).to have_css("dd.trust-level", text: TrustLevel.name(2))
      end
    end

    context "when user has trust level 3" do
      fab!(:user) { Fabricate(:user, trust_level: 3) }
      before { sign_in(user) }

      it "displays the correct trust level element" do
        user_page.visit(user).expand_info_panel
        expect(user_page).to have_css("dd.trust-level", text: TrustLevel.name(3))
      end
    end

    context "when user has trust level 4" do
      fab!(:user) { Fabricate(:user, trust_level: 4) }
      before { sign_in(user) }

      it "displays the correct trust level element" do
        user_page.visit(user).expand_info_panel
        expect(user_page).to have_css("dd.trust-level", text: TrustLevel.name(4))
      end
    end
  end
end
