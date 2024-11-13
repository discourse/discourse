# frozen_string_literal: true

RSpec.describe UserOption do
  describe "#ensure_consistency!" do
    it "recreates missing user option records" do
      user = Fabricate(:user)
      user.user_option.destroy
      UserOption.ensure_consistency!

      user.reload

      expect(user.user_option.email_level).to eq(SiteSetting.default_email_level)
      expect(user.user_option.email_messages_level).to eq(SiteSetting.default_email_messages_level)
    end
  end

  describe "defaults" do
    fab!(:user)

    it "should be redirected to top when there is a reason to" do
      user.user_option.expects(:redirected_to_top).returns(reason: "42")
      expect(user.user_option.should_be_redirected_to_top).to eq(true)
    end

    it "should not be redirected to top when there is no reason to" do
      user.user_option.expects(:redirected_to_top).returns(nil)
      expect(user.user_option.should_be_redirected_to_top).to eq(false)
    end

    it "should not hide the profile and presence by default" do
      expect(user.user_option.hide_profile).to eq(false)
      expect(user.user_option.hide_presence).to eq(false)
    end

    it "should correctly set digest frequency" do
      SiteSetting.default_email_digest_frequency = 1440
      user = Fabricate(:user)
      expect(user.user_option.email_digests).to eq(true)
      expect(user.user_option.digest_after_minutes).to eq(1440)
    end

    it "should correctly set digest frequency when disabled" do
      SiteSetting.default_email_digest_frequency = 0
      user = Fabricate(:user)
      expect(user.user_option.email_digests).to eq(false)
      expect(user.user_option.digest_after_minutes).to eq(0)
    end

    it "should correctly set sidebar_link_to_filtered_list when `default_sidebar_link_to_filtered_list` site setting is enabled" do
      SiteSetting.default_sidebar_link_to_filtered_list = true
      user = Fabricate(:user)
      expect(user.user_option.sidebar_link_to_filtered_list).to eq(true)
    end

    it "should correctly set sidebar_link_to_filtered_list when `default_sidebar_link_to_filtered_list` site setting is disabled" do
      SiteSetting.default_sidebar_link_to_filtered_list = false
      user = Fabricate(:user)
      expect(user.user_option.sidebar_link_to_filtered_list).to eq(false)
    end

    it "should correctly set sidebar_show_count_of_new_items when `default_sidebar_show_count_of_new_items` site setting is enabled" do
      SiteSetting.default_sidebar_show_count_of_new_items = true
      user = Fabricate(:user)
      expect(user.user_option.sidebar_show_count_of_new_items).to eq(true)
    end

    it "should correctly set sidebar_show_count_of_new_items when `default_sidebar_show_count_of_new_items` site setting is disabled" do
      SiteSetting.default_sidebar_show_count_of_new_items = false
      user = Fabricate(:user)
      expect(user.user_option.sidebar_show_count_of_new_items).to eq(false)
    end
  end

  describe "site settings" do
    it "should apply defaults from site settings" do
      SiteSetting.default_other_enable_quoting = false
      SiteSetting.default_other_enable_smart_lists = false
      SiteSetting.default_other_enable_defer = true
      SiteSetting.default_other_external_links_in_new_tab = true
      SiteSetting.default_other_dynamic_favicon = true
      SiteSetting.default_other_skip_new_user_tips = true

      user = Fabricate(:user)

      expect(user.user_option.enable_quoting).to eq(false)
      expect(user.user_option.enable_smart_lists).to eq(false)
      expect(user.user_option.enable_defer).to eq(true)
      expect(user.user_option.external_links_in_new_tab).to eq(true)
      expect(user.user_option.dynamic_favicon).to eq(true)
      expect(user.user_option.skip_new_user_tips).to eq(true)
    end
  end

  describe "#mailing_list_mode" do
    fab!(:forum_user) { Fabricate(:user) }
    fab!(:mailing_list_user) { Fabricate(:user) }

    before do
      forum_user.user_option.update(mailing_list_mode: false)
      mailing_list_user.user_option.update(mailing_list_mode: true)
    end

    it "should return false when `SiteSetting.disable_mailing_list_mode` is enabled" do
      SiteSetting.disable_mailing_list_mode = true
      expect(forum_user.user_option.mailing_list_mode).to eq(false)
      expect(mailing_list_user.user_option.mailing_list_mode).to eq(false)
    end

    it "should return the stored value when `SiteSetting.disable_mailing_list_mode` is disabled" do
      SiteSetting.disable_mailing_list_mode = false
      expect(forum_user.user_option.mailing_list_mode).to eq(false)
      expect(mailing_list_user.user_option.mailing_list_mode).to eq(true)
    end
  end

  describe ".redirected_to_top" do
    fab!(:user)

    it "should have no reason when `SiteSetting.redirect_users_to_top_page` is disabled" do
      SiteSetting.redirect_users_to_top_page = false
      expect(user.user_option.redirected_to_top).to eq(nil)
    end

    context "when `SiteSetting.redirect_users_to_top_page` is enabled" do
      before { SiteSetting.redirect_users_to_top_page = true }

      it "should have no reason when top is not in the `SiteSetting.top_menu`" do
        SiteSetting.top_menu = "latest"
        expect(user.user_option.redirected_to_top).to eq(nil)
      end

      context "when top is in the `SiteSetting.top_menu`" do
        before { SiteSetting.top_menu = "latest|top" }

        it "should have no reason when there are not enough topics" do
          SiteSetting.expects(:min_redirected_to_top_period).returns(nil)
          expect(user.user_option.redirected_to_top).to eq(nil)
        end

        context "when there are enough topics" do
          before { SiteSetting.expects(:min_redirected_to_top_period).returns(:monthly) }

          describe "a new user" do
            before do
              user.stubs(:trust_level).returns(0)
              user.stubs(:last_seen_at).returns(5.minutes.ago)
            end

            after { Discourse.redis.flushdb }

            it "should have a reason for the first visit" do
              freeze_time do
                delay = SiteSetting.active_user_rate_limit_secs / 2

                expect_enqueued_with(
                  job: :update_top_redirection,
                  args: {
                    user_id: user.id,
                    redirected_at: Time.zone.now.to_s,
                  },
                  at: Time.zone.now + delay,
                ) do
                  expect(user.user_option.redirected_to_top).to eq(
                    reason: I18n.t("redirected_to_top_reasons.new_user"),
                    period: :monthly,
                  )
                end
              end
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

              expect(user.user_option.redirected_to_top).to eq(
                reason: I18n.t("redirected_to_top_reasons.not_seen_in_a_month"),
                period: :monthly,
              )
            end
          end
        end
      end
    end
  end

  describe ".user_tzinfo" do
    fab!(:user)

    context "with user with valid timezone given" do
      before { user.user_option.update(timezone: "Europe/Paris") }

      it "returns the expect timezone" do
        expect(UserOption.user_tzinfo(user.id)).to eq(
          ActiveSupport::TimeZone.find_tzinfo("Europe/Paris"),
        )
      end

      it "works for Europe/Kyiv" do
        user.user_option.update(timezone: "Europe/Kyiv")
        expect(UserOption.user_tzinfo(user.id)).to eq(
          ActiveSupport::TimeZone.find_tzinfo("Europe/Kyiv"),
        )
      end
    end

    context "with user with invalid timezone given" do
      before { user.user_option.update(timezone: "Catopia/Catcity") }

      it "fallbacks to UTC" do
        expect(UserOption.user_tzinfo(user.id)).to eq(ActiveSupport::TimeZone.find_tzinfo("UTC"))
      end
    end
  end
end
