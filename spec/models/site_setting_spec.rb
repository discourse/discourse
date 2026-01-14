# frozen_string_literal: true

RSpec.describe SiteSetting do
  describe "topic_title_length" do
    it "returns a range of min/max topic title length" do
      expect(SiteSetting.topic_title_length).to eq(
        SiteSetting.min_topic_title_length..SiteSetting.max_topic_title_length,
      )
    end
  end

  describe "post_length" do
    it "returns a range of min/max post length" do
      expect(SiteSetting.post_length).to eq(
        SiteSetting.min_post_length..SiteSetting.max_post_length,
      )
    end
  end

  describe "first_post_length" do
    it "returns a range of min/max first post length" do
      expect(SiteSetting.first_post_length).to eq(
        SiteSetting.min_first_post_length..SiteSetting.max_post_length,
      )
    end
  end

  describe "private_message_title_length" do
    it "returns a range of min/max pm topic title length" do
      expect(SiteSetting.private_message_title_length).to eq(
        SiteSetting.min_personal_message_title_length..SiteSetting.max_topic_title_length,
      )
    end
  end

  describe "in test we do some judo to ensure SiteSetting is always reset between tests" do
    it "is always the correct default" do
      expect(SiteSetting.contact_email).to eq("")
    end

    it "sets a setting" do
      SiteSetting.contact_email = "sam@sam.com"
    end
  end

  describe "anonymous_homepage" do
    it "returns latest" do
      expect(SiteSetting.anonymous_homepage).to eq("latest")
    end
  end

  describe "top_menu" do
    describe "validations" do
      it "always demands latest" do
        expect do SiteSetting.top_menu = "categories" end.to raise_error(
          Discourse::InvalidParameters,
        )
      end

      it "does not allow random text" do
        expect do SiteSetting.top_menu = "latest|random" end.to raise_error(
          Discourse::InvalidParameters,
        )
      end
    end

    describe "items" do
      let(:items) { SiteSetting.top_menu_items }

      it "returns TopMenuItem objects" do
        expect(items[0]).to be_kind_of(TopMenuItem)
      end
    end

    describe "homepage" do
      it "has homepage" do
        SiteSetting.top_menu = "bookmarks|latest"
        expect(SiteSetting.homepage).to eq("bookmarks")
      end
    end
  end

  describe "min_redirected_to_top_period" do
    context "when has_enough_top_topics" do
      before do
        SiteSetting.topics_per_period_in_top_page = 2
        SiteSetting.top_page_default_timeframe = "daily"

        2.times { TopTopic.create!(daily_score: 2.5) }

        TopTopic.refresh!
      end

      it "should_return_a_time_period" do
        expect(SiteSetting.min_redirected_to_top_period(1.day.ago)).to eq(:daily)
      end
    end

    context "when does_not_have_enough_top_topics" do
      before do
        SiteSetting.topics_per_period_in_top_page = 20
        SiteSetting.top_page_default_timeframe = "daily"
        TopTopic.refresh!
      end

      it "should_return_a_time_period" do
        expect(SiteSetting.min_redirected_to_top_period(1.day.ago)).to eq(nil)
      end
    end
  end

  describe "scheme" do
    before { SiteSetting.force_https = true }

    it "returns http when ssl is disabled" do
      SiteSetting.force_https = false
      expect(SiteSetting.scheme).to eq("http")
    end

    it "returns https when using ssl" do
      expect(SiteSetting.scheme).to eq("https")
    end
  end

  describe ".shared_drafts_enabled?" do
    it "returns false by default" do
      expect(SiteSetting.shared_drafts_enabled?).to eq(false)
    end

    it "returns false when the category is uncategorized" do
      SiteSetting.shared_drafts_category = SiteSetting.uncategorized_category_id
      expect(SiteSetting.shared_drafts_enabled?).to eq(false)
    end

    it "returns true when the category is valid" do
      SiteSetting.shared_drafts_category = Fabricate(:category).id
      expect(SiteSetting.shared_drafts_enabled?).to eq(true)
    end
  end

  describe "cached settings" do
    it "should recalculate cached setting when dependent settings are changed" do
      SiteSetting.blocked_attachment_filenames = "foo"
      expect(SiteSetting.blocked_attachment_filenames_regex).to eq(/foo/)

      SiteSetting.blocked_attachment_filenames = "foo|bar"
      expect(SiteSetting.blocked_attachment_filenames_regex).to eq(/foo|bar/)
    end
  end

  it "sanitizes the client settings when they are overridden" do
    xss = "<b onmouseover=alert('Wufff!')>click me!</b><script>alert('TEST');</script>"

    SiteSetting.global_notice = xss

    expect(SiteSetting.global_notice).to eq("<b>click me!</b>alert('TEST');")
  end

  it "doesn't corrupt site settings with special characters" do
    value = 'OX5y3Oljb+Qt9Bu809vsBQ==<>!%{}*&!@#$%..._-A'
    settings = new_settings(SiteSettings::LocalProcessProvider.new)
    settings.setting(:test_setting, "", client: true)

    settings.test_setting = value

    expect(settings.test_setting).to eq(value)
  end

  describe "#all_settings" do
    it "does not include the `default_locale` setting if include_locale_setting is false" do
      expect(SiteSetting.all_settings.map { |s| s[:setting] }).to include("default_locale")
      expect(
        SiteSetting.all_settings(include_locale_setting: false).map { |s| s[:setting] },
      ).not_to include("default_locale")
    end

    it "does not include the `default_locale` setting if filter_categories are specified" do
      expect(
        SiteSetting.all_settings(filter_categories: ["branding"]).map { |s| s[:setting] },
      ).not_to include("default_locale")
    end

    it "does not include the `default_locale` setting if filter_plugin is specified" do
      expect(
        SiteSetting.all_settings(filter_plugin: "chat").map { |s| s[:setting] },
      ).not_to include("default_locale")
    end

    it "includes only settings for the specified category" do
      expect(SiteSetting.all_settings(filter_categories: ["required"]).count).to eq(12)
    end
  end

  describe ".history_for" do
    fab!(:admin)

    it "returns an empty relation when no changes have been made" do
      expect(SiteSetting.history_for(:title)).to be_empty
    end

    it "returns UserHistory records for the specified setting" do
      StaffActionLogger.new(admin).log_site_setting_change(:title, "Old Title", "New Title")
      StaffActionLogger.new(admin).log_site_setting_change(:title, "New Title", "Newer Title")

      history = SiteSetting.history_for(:title)

      expect(history.count).to eq(2)
      expect(history.first.action).to eq(UserHistory.actions[:change_site_setting])
      expect(history.first.subject).to eq("title")
      expect(history.first.new_value).to eq("Newer Title")
      expect(history.last.new_value).to eq("New Title")
    end

    it "returns only records for the specified setting" do
      StaffActionLogger.new(admin).log_site_setting_change(:title, "Old", "New")
      StaffActionLogger.new(admin).log_site_setting_change(
        :contact_email,
        "old@test.com",
        "new@test.com",
      )

      history = SiteSetting.history_for(:title)

      expect(history.count).to eq(1)
      expect(history.first.subject).to eq("title")
    end

    it "returns records ordered by most recent first" do
      StaffActionLogger.new(admin).log_site_setting_change(:title, "First", "Second")
      StaffActionLogger.new(admin).log_site_setting_change(:title, "Second", "Third")

      history = SiteSetting.history_for(:title)

      expect(history.first.new_value).to eq("Third")
      expect(history.last.new_value).to eq("Second")
    end
  end

  describe "ImageQuality" do
    describe "#png_to_jpg_quality" do
      context "when set to zero" do
        before { SiteSetting.png_to_jpg_quality = 0 }

        it "falls back to unified image quality setting" do
          expect(SiteSetting.ImageQuality.png_to_jpg_quality).to eq(SiteSetting.image_quality)
        end
      end

      context "when set to any non-zero value" do
        before { SiteSetting.png_to_jpg_quality = 42 }

        it "uses the configured value" do
          expect(SiteSetting.ImageQuality.png_to_jpg_quality).to eq(42)
        end
      end
    end

    describe "#recompress_original_jpg_quality" do
      context "when set to zero" do
        before { SiteSetting.recompress_original_jpg_quality = 0 }

        it "falls back to unified image quality setting" do
          expect(SiteSetting.ImageQuality.recompress_original_jpg_quality).to eq(
            SiteSetting.image_quality,
          )
        end
      end

      context "when set to any non-zero value" do
        before { SiteSetting.recompress_original_jpg_quality = 42 }

        it "uses the configured value" do
          expect(SiteSetting.ImageQuality.recompress_original_jpg_quality).to eq(42)
        end
      end
    end

    describe "#image_preview_jpg_quality" do
      context "when set to zero" do
        before { SiteSetting.image_preview_jpg_quality = 0 }

        it "falls back to unified image quality setting" do
          expect(SiteSetting.ImageQuality.image_preview_jpg_quality).to eq(
            SiteSetting.image_quality,
          )
        end
      end

      context "when set to any non-zero value" do
        before { SiteSetting.image_preview_jpg_quality = 42 }

        it "uses the configured value" do
          expect(SiteSetting.ImageQuality.image_preview_jpg_quality).to eq(42)
        end
      end
    end
  end

  describe "creating upload references for type objects settings with upload fields" do
    let(:provider) { SiteSettings::DbProvider.new(SiteSetting) }
    fab!(:upload)
    fab!(:upload2, :upload)

    it "creates upload references for objects with upload fields" do
      objects_value =
        JSON.generate(
          [
            { "name" => "object1", "upload_id" => upload.id },
            { "name" => "object2", "upload_id" => upload2.id },
          ],
        )

      expect {
        provider.save(
          "test_objects_with_uploads",
          objects_value,
          SiteSettings::TypeSupervisor.types[:objects],
        )
      }.to change { UploadReference.count }.by(2)

      upload_references =
        UploadReference.where(target: SiteSetting.find_by(name: "test_objects_with_uploads"))

      expect(upload_references.pluck(:upload_id)).to contain_exactly(upload.id, upload2.id)

      expect { provider.destroy("test_objects_with_uploads") }.to change {
        UploadReference.count
      }.by(-2)
    end

    it "creates upload references for objects with upload URLs" do
      objects_value =
        JSON.generate(
          [
            { "name" => "object1", "upload_id" => upload.url },
            { "name" => "object2", "upload_id" => upload2.url },
          ],
        )

      expect {
        provider.save(
          "test_objects_with_uploads",
          objects_value,
          SiteSettings::TypeSupervisor.types[:objects],
        )
      }.to change { UploadReference.count }.by(2)

      upload_references =
        UploadReference.where(target: SiteSetting.find_by(name: "test_objects_with_uploads"))

      expect(upload_references.pluck(:upload_id)).to contain_exactly(upload.id, upload2.id)
    end

    it "removes upload references when uploads are removed from objects" do
      # First save with two uploads
      objects_value =
        JSON.generate(
          [
            { "name" => "object1", "upload_id" => upload.url },
            { "name" => "object2", "upload_id" => upload2.url },
          ],
        )

      provider.save(
        "test_objects_with_uploads",
        objects_value,
        SiteSettings::TypeSupervisor.types[:objects],
      )

      setting = SiteSetting.find_by(name: "test_objects_with_uploads")
      expect(UploadReference.where(target: setting).count).to eq(2)

      # Now save with only one upload - should remove the other reference
      objects_value_updated = JSON.generate([{ "name" => "object1", "upload_id" => upload.url }])

      expect {
        provider.save(
          "test_objects_with_uploads",
          objects_value_updated,
          SiteSettings::TypeSupervisor.types[:objects],
        )
      }.to change { UploadReference.count }.by(-1)

      expect(UploadReference.where(target: setting).pluck(:upload_id)).to contain_exactly(upload.id)
    end

    it "removes all upload references when all uploads are removed from objects" do
      # First save with uploads
      objects_value =
        JSON.generate(
          [
            { "name" => "object1", "upload_id" => upload.url },
            { "name" => "object2", "upload_id" => upload2.url },
          ],
        )

      provider.save(
        "test_objects_with_uploads",
        objects_value,
        SiteSettings::TypeSupervisor.types[:objects],
      )

      setting = SiteSetting.find_by(name: "test_objects_with_uploads")
      expect(UploadReference.where(target: setting).count).to eq(2)

      # Now save with no uploads - should remove all references
      objects_value_empty = JSON.generate([{ "name" => "object1" }])

      expect {
        provider.save(
          "test_objects_with_uploads",
          objects_value_empty,
          SiteSettings::TypeSupervisor.types[:objects],
        )
      }.to change { UploadReference.count }.by(-2)

      expect(UploadReference.where(target: setting).count).to eq(0)
    end
  end

  describe "Upload" do
    before { setup_s3 }

    describe "#use_dualstack_endpoint" do
      context "when the s3 endpoint has been set" do
        before { SiteSetting.s3_endpoint = "https://s3clone.test.com" }

        it "returns false " do
          expect(SiteSetting.Upload.use_dualstack_endpoint).to eq(false)
        end
      end

      context "when enable_s3_uploads is false" do
        before { SiteSetting.enable_s3_uploads = false }

        it "returns false" do
          expect(SiteSetting.Upload.use_dualstack_endpoint).to eq(false)
        end
      end

      context "when enable_s3_uploads is true" do
        before do
          SiteSetting.enable_s3_uploads = true
          SiteSetting.s3_endpoint = ""
        end

        it "returns false if the s3_region is in China" do
          SiteSetting.s3_region = "cn-north-1"
          expect(SiteSetting.Upload.use_dualstack_endpoint).to eq(false)
        end

        it "returns true if the s3_region is not in China" do
          SiteSetting.s3_region = "us-west-1"
          expect(SiteSetting.Upload.use_dualstack_endpoint).to eq(true)
        end
      end
    end
  end
end
