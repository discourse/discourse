# frozen_string_literal: true

describe "Content localization site setting changes" do
  describe "when content_localization_enabled is enabled" do
    it "adds addTranslation button to post_menu after edit button" do
      original_menu = "read|like|edit|reply"
      SiteSetting.post_menu = original_menu

      SiteSetting.content_localization_enabled = true

      expect(SiteSetting.post_menu).to eq("read|like|edit|addTranslation|reply")
    end

    it "adds addTranslation as first button when edit button does not exist" do
      original_menu = "read|like|reply"
      SiteSetting.post_menu = original_menu

      SiteSetting.content_localization_enabled = true

      expect(SiteSetting.post_menu).to eq("addTranslation|read|like|reply")
    end

    it "does not add addTranslation if it already exists in post_menu" do
      original_menu = "read|like|edit|addTranslation|reply"
      SiteSetting.post_menu = original_menu

      SiteSetting.content_localization_enabled = true

      expect(SiteSetting.post_menu).to eq("read|like|edit|addTranslation|reply")
    end

    it "does not modify post_menu when setting is disabled" do
      original_menu = "read|like|edit|reply"
      SiteSetting.post_menu = original_menu

      SiteSetting.content_localization_enabled = false

      expect(SiteSetting.post_menu).to eq("read|like|edit|reply")
    end
  end
end
