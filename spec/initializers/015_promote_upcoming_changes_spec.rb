# frozen_string_literal: true

describe "Promote upcoming changes initializer" do
  context "when enable_upcoming_changes is disabled" do
    before do
      SiteSetting.enable_upcoming_changes = false
      SiteSetting.promote_upcoming_changes_on_status = :stable
    end

    it "does nothing" do
      SiteSetting.expects(:upcoming_change_site_settings).never
      UpcomingChanges::AutoPromotionInitializer.call
    end
  end

  context "when enable_upcoming_changes is enabled" do
    before do
      SiteSetting.enable_upcoming_changes = true
      SiteSetting.upcoming_change_verbose_logging = true

      mock_upcoming_change_metadata(
        {
          enable_upload_debug_mode: {
            impact: "other,developers",
            status: :stable,
            impact_type: "other",
            impact_role: "developers",
          },
          enable_user_tips: {
            impact: "feature,all_members",
            status: :beta,
            impact_type: "feature",
            impact_role: "all_members",
          },
          show_user_menu_avatars: {
            impact: "feature,all_members",
            status: :permanent,
            impact_type: "feature",
            impact_role: "all_members",
          },
        },
      )
    end

    context "when the change does not meet the promotion criteria" do
      before { SiteSetting.promote_upcoming_changes_on_status = :never }

      it "does not enable the upcoming change and logs output" do
        track_log_messages do |logger|
          UpcomingChanges::AutoPromotionInitializer.call
          expect(logger.warnings.join("\n")).to include(
            "'enable_upload_debug_mode' did not meet promotion criteria. Current status is stable, required status is never.",
          )
          expect(logger.warnings.join("\n")).to include(
            "'enable_user_tips' did not meet promotion criteria. Current status is beta, required status is never.",
          )
        end
      end
    end

    context "when the upcoming change has already been set by the admin" do
      before do
        SiteSetting.enable_upload_debug_mode = true
        DB.exec(
          "INSERT INTO site_settings (name, value, data_type, created_at, updated_at)
          VALUES ('enable_upload_debug_mode', 'false', 5, NOW(), NOW())",
        )
      end

      after { DB.exec("DELETE FROM site_settings WHERE name = 'enable_upload_debug_mode'") }

      it "does not enable the upcoming change and logs output" do
        track_log_messages do |logger|
          UpcomingChanges::AutoPromotionInitializer.call
          expect(logger.warnings.join("\n")).to include(
            "'enable_upload_debug_mode' has already been modified by an admin, skipping promotion.",
          )
        end
      end

      context "when the upcoming change has reached the permanent state" do
        before do
          DB.exec(
            "INSERT INTO site_settings (name, value, data_type, created_at, updated_at)
          VALUES ('show_user_menu_avatars', 'false', 5, NOW(), NOW())",
          )
        end

        it "does enable the upcoming change and logs output" do
          track_log_messages do |logger|
            UpcomingChanges::AutoPromotionInitializer.call
            expect(logger.infos.join("\n")).to include(
              /Successfully promoted 'show_user_menu_avatars' to enabled/,
            )
          end
          expect(SiteSetting.show_user_menu_avatars).to be(true)
        end
      end
    end

    context "when the upcoming change is already enabled" do
      before { SiteSetting.enable_upload_debug_mode = true }

      it "does not enable the upcoming change and logs output" do
        track_log_messages do |logger|
          UpcomingChanges::AutoPromotionInitializer.call
          expect(logger.warnings.join("\n")).to include(
            "'enable_upload_debug_mode' is already enabled, skipping promotion.",
          )
        end
      end
    end

    context "when the UpcomingChanges::Toggle service has an unexpected failure" do
      it "does not enable the upcoming change and logs output" do
        failing_toggle =
          Class.new(UpcomingChanges::Toggle) do
            def run!
              context.fail(error: "Simulated failure")
              raise Service::Base::Failure.new(context)
            end
          end

        stub_const(UpcomingChanges, "Toggle", failing_toggle) do
          track_log_messages do |logger|
            UpcomingChanges::AutoPromotionInitializer.call
            expect(logger.errors.join("\n")).to include(
              "Failed to promote 'enable_upload_debug_mode' via toggle_upcoming_change, an unexpected error occurred.",
            )
          end
        end
      end
    end

    context "when everything is ok" do
      it "enables the upcoming change and logs output" do
        track_log_messages do |logger|
          UpcomingChanges::AutoPromotionInitializer.call
          expect(logger.infos.join("\n")).to include(
            /Successfully promoted 'enable_upload_debug_mode' to enabled/,
          )
        end
        expect(SiteSetting.enable_upload_debug_mode).to be(true)
      end

      it "does not enable an upcoming change that does not meet promotion status criteria" do
        track_log_messages do |logger|
          UpcomingChanges::AutoPromotionInitializer.call
          expect(logger.warnings.join("\n")).to include(
            /'enable_user_tips' did not meet promotion criteria. Current status is beta, required status is stable./,
          )
        end
        expect(SiteSetting.enable_upload_debug_mode).to be(true)
      end
    end
  end
end
