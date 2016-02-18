require 'rails_helper'
require_dependency 'user_option'

describe UserOption do

  describe "should_be_redirected_to_top" do
    let!(:user) { Fabricate(:user) }

    it "should be redirected to top when there is a reason to" do
      user.user_option.expects(:redirected_to_top).returns({ reason: "42" })
      expect(user.user_option.should_be_redirected_to_top).to eq(true)
    end

    it "should not be redirected to top when there is no reason to" do
      user.user_option.expects(:redirected_to_top).returns(nil)
      expect(user.user_option.should_be_redirected_to_top).to eq(false)
    end

  end

  describe ".redirected_to_top" do
    let!(:user) { Fabricate(:user) }

    it "should have no reason when `SiteSetting.redirect_users_to_top_page` is disabled" do
      SiteSetting.expects(:redirect_users_to_top_page).returns(false)
      expect(user.user_option.redirected_to_top).to eq(nil)
    end

    context "when `SiteSetting.redirect_users_to_top_page` is enabled" do
      before { SiteSetting.expects(:redirect_users_to_top_page).returns(true) }

      it "should have no reason when top is not in the `SiteSetting.top_menu`" do
        SiteSetting.expects(:top_menu).returns("latest")
        expect(user.user_option.redirected_to_top).to eq(nil)
      end

      context "and when top is in the `SiteSetting.top_menu`" do
        before { SiteSetting.expects(:top_menu).returns("latest|top") }

        it "should have no reason when there are not enough topics" do
          SiteSetting.expects(:min_redirected_to_top_period).returns(nil)
          expect(user.user_option.redirected_to_top).to eq(nil)
        end

        context "and there are enough topics" do

          before { SiteSetting.expects(:min_redirected_to_top_period).returns(:monthly) }

          describe "a new user" do
            before do
              user.stubs(:trust_level).returns(0)
              user.stubs(:last_seen_at).returns(5.minutes.ago)
            end

            it "should have a reason for the first visit" do
              expect(user.user_option.redirected_to_top).to eq({
                reason: I18n.t('redirected_to_top_reasons.new_user'),
                period: :monthly
              })
            end

            it "should not have a reason for next visits" do
              user.user_option.expects(:last_redirected_to_top_at).returns(10.minutes.ago)
              user.user_option.expects(:update_last_redirected_to_top!).never

              expect(user.user_option.redirected_to_top).to eq(nil)
            end
          end

          describe "an older user" do
            before { user.stubs(:trust_level).returns(1) }

            it "should have a reason when the user hasn't been seen in a month" do
              user.last_seen_at = 2.months.ago
              user.user_option.expects(:update_last_redirected_to_top!).once

              expect(user.user_option.redirected_to_top).to eq({
                reason: I18n.t('redirected_to_top_reasons.not_seen_in_a_month'),
                period: :monthly
              })
            end

          end

        end

      end

    end

  end
end
