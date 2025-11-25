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

    it "adds addTranslation button to post_menu_hidden_items after edit button" do
      original_hidden_items = "flag|bookmark|edit|delete|admin"
      SiteSetting.post_menu_hidden_items = original_hidden_items

      SiteSetting.content_localization_enabled = true

      expect(SiteSetting.post_menu_hidden_items).to eq(
        "flag|bookmark|edit|addTranslation|delete|admin",
      )
    end

    it "adds addTranslation to post_menu_hidden_items as first button when edit button does not exist" do
      original_hidden_items = "flag|bookmark|delete|admin"
      SiteSetting.post_menu_hidden_items = original_hidden_items

      SiteSetting.content_localization_enabled = true

      expect(SiteSetting.post_menu_hidden_items).to eq("addTranslation|flag|bookmark|delete|admin")
    end

    it "does not add addTranslation if it already exists in post_menu_hidden_items" do
      original_hidden_items = "flag|bookmark|edit|addTranslation|delete|admin"
      SiteSetting.post_menu_hidden_items = original_hidden_items

      SiteSetting.content_localization_enabled = true

      expect(SiteSetting.post_menu_hidden_items).to eq(
        "flag|bookmark|edit|addTranslation|delete|admin",
      )
    end

    it "does not modify post_menu_hidden_items when setting is disabled" do
      original_hidden_items = "flag|bookmark|edit|delete|admin"
      SiteSetting.post_menu_hidden_items = original_hidden_items

      SiteSetting.content_localization_enabled = false

      expect(SiteSetting.post_menu_hidden_items).to eq("flag|bookmark|edit|delete|admin")
    end
  end
end
