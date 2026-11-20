# frozen_string_literal: true

RSpec.describe Rtl do
  let(:user) { Fabricate.build(:user) }

  describe ".css_class" do
    it "uses the effective locale when the saved language is excluded" do
      SiteSetting.allowed_user_locales = "fr"
      user.locale = "he"
      expect(Rtl.new(user).css_class).to eq("")

      SiteSetting.default_locale = "he"
      user.locale = "en"
      expect(Rtl.new(user).css_class).to eq("rtl")
    end

    context "when user locale is allowed" do
      before { SiteSetting.allowed_user_locales = "all" }

      context "when user locale is RTL" do
        before { user.locale = "he" }

        it "returns rtl class" do
          expect(Rtl.new(user).css_class).to eq("rtl")
        end
      end

      context "when user locale is not RTL" do
        it "returns empty class" do
          expect(Rtl.new(user).css_class).to eq("")
        end
      end
    end

    context "when user locale is not allowed" do
      before { SiteSetting.allowed_user_locales = "" }

      context "when site default locale is RTL" do
        before { SiteSetting.default_locale = "he" }

        it "returns rtl class" do
          expect(Rtl.new(user).css_class).to eq("rtl")
        end
      end

      context "when site default locale is LTR" do
        before { SiteSetting.default_locale = "en" }

        context "when user locale is RTL" do
          before { user.stubs(:locale).returns("he") }

          it "returns empty class" do
            expect(Rtl.new(user).css_class).to eq("")
          end
        end
      end
    end
  end
end
