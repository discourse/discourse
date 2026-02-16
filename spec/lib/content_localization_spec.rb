# frozen_string_literal: true

describe ContentLocalization do
  def create_scope(cookie: nil)
    env = create_request_env.merge("HTTP_COOKIE" => cookie)
    mock().tap { |m| m.stubs(:request).returns(ActionDispatch::Request.new(env)) }
  end

  describe ".show_original" do
    it "returns true when cookie is present" do
      scope = create_scope(cookie: ContentLocalization::SHOW_ORIGINAL_COOKIE)

      expect(ContentLocalization.show_original?(scope)).to be true
    end

    it "returns false when cookie is absent" do
      scope = create_scope

      expect(ContentLocalization.show_original?(scope)).to be false
    end
  end

  describe ".show_translated_post?" do
    fab!(:post)

    it "returns true when criteria met" do
      SiteSetting.content_localization_enabled = true
      post.update!(locale: "ja")
      I18n.locale = "de"
      scope = create_scope

      expect(ContentLocalization.show_translated_post?(post, scope)).to be true
    end

    context "when criteria not met" do
      before do
        SiteSetting.content_localization_enabled = true
        post.update!(locale: "ja")
        I18n.locale = "de"
      end

      it "returns false when content_localization_enabled is false" do
        SiteSetting.content_localization_enabled = false
        scope = create_scope

        expect(ContentLocalization.show_translated_post?(post, scope)).to be false
      end

      it "returns false when post raw is nil" do
        post.update_columns(raw: "")
        scope = create_scope

        expect(ContentLocalization.show_translated_post?(post, scope)).to be false
      end

      it "returns false when post locale is nil" do
        post.update!(locale: nil)
        scope = create_scope

        expect(ContentLocalization.show_translated_post?(post, scope)).to be false
      end

      it "returns false when post is in user locale" do
        post.update!(locale: I18n.locale)
        scope = create_scope

        expect(ContentLocalization.show_translated_post?(post, scope)).to be false
      end

      it "returns false when show_original? is true" do
        scope = create_scope(cookie: ContentLocalization::SHOW_ORIGINAL_COOKIE)

        expect(ContentLocalization.show_translated_post?(post, scope)).to be false
      end
    end
  end

  describe ".show_translated_topic?" do
    fab!(:topic)

    it "returns true when criteria met" do
      SiteSetting.content_localization_enabled = true
      topic.update!(locale: "ja")
      I18n.locale = "de"
      scope = create_scope

      expect(ContentLocalization.show_translated_topic?(topic, scope)).to be true
    end

    context "when criteria not met" do
      before do
        SiteSetting.content_localization_enabled = true
        topic.update!(locale: "ja")
        I18n.locale = "de"
      end

      it "returns false when content_localization_enabled is false" do
        SiteSetting.content_localization_enabled = false
        scope = create_scope

        expect(ContentLocalization.show_translated_topic?(topic, scope)).to be false
      end

      it "returns false when topic locale is nil" do
        topic.update!(locale: nil)
        scope = create_scope

        expect(ContentLocalization.show_translated_topic?(topic, scope)).to be false
      end

      it "returns false when topic is in user locale" do
        topic.update!(locale: I18n.locale)
        scope = create_scope

        expect(ContentLocalization.show_translated_topic?(topic, scope)).to be false
      end

      it "returns false when show_original? is true" do
        scope = create_scope(cookie: ContentLocalization::SHOW_ORIGINAL_COOKIE)

        expect(ContentLocalization.show_translated_topic?(topic, scope)).to be false
      end
    end
  end

  describe ".show_translated_category?" do
    fab!(:category)

    it "returns false when setting is disabled" do
      SiteSetting.content_localization_enabled = false
      category.update!(locale: "ja")
      I18n.locale = "de"
      scope = create_scope

      expect(ContentLocalization.show_translated_category?(category, scope)).to be false
    end

    it "returns true when category locale does not match user locale" do
      SiteSetting.content_localization_enabled = true
      category.update!(locale: "ja")
      I18n.locale = "de"
      scope = create_scope

      expect(ContentLocalization.show_translated_category?(category, scope)).to be true
    end

    it "returns false when category locale does not match user locale but cookie set to show original" do
      SiteSetting.content_localization_enabled = true
      category.update!(locale: "ja")
      I18n.locale = "de"
      scope = create_scope(cookie: ContentLocalization::SHOW_ORIGINAL_COOKIE)

      expect(ContentLocalization.show_translated_category?(category, scope)).to be false
    end

    it "returns false when category locale is nil" do
      SiteSetting.content_localization_enabled = true
      category.update!(locale: nil)
      I18n.locale = "de"
      scope = create_scope

      expect(ContentLocalization.show_translated_category?(category, scope)).to be false
    end
  end

  describe ".show_translated_tag?" do
    fab!(:tag)

    it "returns true when criteria met" do
      SiteSetting.content_localization_enabled = true
      tag.update!(locale: "ja")
      I18n.locale = "de"
      scope = create_scope

      expect(ContentLocalization.show_translated_tag?(tag, scope)).to be true
    end

    context "when criteria not met" do
      before do
        SiteSetting.content_localization_enabled = true
        tag.update!(locale: "ja")
        I18n.locale = "de"
      end

      it "returns false when content_localization_enabled is false" do
        SiteSetting.content_localization_enabled = false
        scope = create_scope

        expect(ContentLocalization.show_translated_tag?(tag, scope)).to be false
      end

      it "returns false when tag locale is nil" do
        tag.update!(locale: nil)
        scope = create_scope

        expect(ContentLocalization.show_translated_tag?(tag, scope)).to be false
      end

      it "returns false when tag is in user locale" do
        tag.update!(locale: I18n.locale)
        scope = create_scope

        expect(ContentLocalization.show_translated_tag?(tag, scope)).to be false
      end

      it "returns false when show_original? is true" do
        scope = create_scope(cookie: ContentLocalization::SHOW_ORIGINAL_COOKIE)

        expect(ContentLocalization.show_translated_tag?(tag, scope)).to be false
      end
    end
  end
end
