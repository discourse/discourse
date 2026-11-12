# frozen_string_literal: true

describe ContentLocalization do
  def create_scope(cookie: nil, user: nil)
    env = create_request_env.merge("HTTP_COOKIE" => cookie)
    mock().tap do |m|
      m.stubs(:request).returns(ActionDispatch::Request.new(env))
      m.stubs(:user).returns(user)
    end
  end

  describe ".automatically_translate?" do
    it "defaults to true for anonymous users and supports the positive cookie" do
      expect(ContentLocalization.automatically_translate?(create_scope)).to be true
      expect(
        ContentLocalization.automatically_translate?(
          create_scope(cookie: "#{ContentLocalization::AUTOMATICALLY_TRANSLATE_COOKIE}=true"),
        ),
      ).to be true
      expect(
        ContentLocalization.automatically_translate?(
          create_scope(cookie: "#{ContentLocalization::AUTOMATICALLY_TRANSLATE_COOKIE}=false"),
        ),
      ).to be false
    end

    it "always uses the logged-in user's preference instead of cookies" do
      user = Fabricate(:user)
      user.user_option.update!(automatically_translate: false)

      expect(ContentLocalization.automatically_translate?(create_scope(user: user))).to be false

      user.user_option.update!(automatically_translate: true)
      scope =
        create_scope(user:, cookie: "#{ContentLocalization::AUTOMATICALLY_TRANSLATE_COOKIE}=false")

      expect(ContentLocalization.automatically_translate?(scope)).to be true
    end
  end

  describe ".understands?" do
    it "matches the logged-in user's languages using normalized locales" do
      user = Fabricate(:user)
      user.user_option.update!(understood_languages: %w[en_GB ja])
      scope = create_scope(user:)

      expect(ContentLocalization.understands?("en", scope)).to be true
      expect(ContentLocalization.understands?("ja-JP", scope)).to be true
      expect(ContentLocalization.understands?("de", scope)).to be false
      expect(ContentLocalization.understands?("en", create_scope)).to be false
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

      it "returns false when automatic translation is disabled" do
        scope = create_scope(cookie: "#{ContentLocalization::AUTOMATICALLY_TRANSLATE_COOKIE}=false")

        expect(ContentLocalization.show_translated_post?(post, scope)).to be false
      end

      it "returns false when the user understands the post's language" do
        user = Fabricate(:user)
        user.user_option.update!(understood_languages: ["ja"])
        scope = create_scope(user:)

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

      it "returns false when automatic translation is disabled" do
        scope = create_scope(cookie: "#{ContentLocalization::AUTOMATICALLY_TRANSLATE_COOKIE}=false")

        expect(ContentLocalization.show_translated_topic?(topic, scope)).to be false
      end

      it "returns false when the user understands the topic's language" do
        user = Fabricate(:user)
        user.user_option.update!(understood_languages: ["ja"])
        scope = create_scope(user:)

        expect(ContentLocalization.show_translated_topic?(topic, scope)).to be false
      end
    end
  end

  describe "translated value helpers" do
    fab!(:post)

    before do
      SiteSetting.content_localization_enabled = true
      post.topic.update!(locale: "ja")
      post.update!(locale: "ja")
      I18n.locale = "de"
    end

    it "returns the localization, or nil when there is none or no record" do
      scope = create_scope

      expect(ContentLocalization.translated_post_cooked(post, scope)).to be_nil
      expect(ContentLocalization.translated_topic_title(post.topic, scope)).to be_nil
      expect(ContentLocalization.translated_post_cooked(nil, scope)).to be_nil
      expect(ContentLocalization.translated_topic_title(nil, scope)).to be_nil

      Fabricate(:post_localization, post: post, locale: "de", cooked: "<p>uebersetzt</p>")
      Fabricate(
        :topic_localization,
        topic: post.topic,
        locale: "de",
        title: "Titel",
        fancy_title: "Fancy Titel",
      )
      post.reload.topic.reload

      expect(ContentLocalization.translated_post_cooked(post, scope)).to eq("<p>uebersetzt</p>")
      expect(ContentLocalization.translated_topic_title(post.topic, scope)).to eq("Titel")
      expect(ContentLocalization.translated_topic_fancy_title(post.topic, scope)).to eq(
        "Fancy Titel",
      )
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
    end
  end
end
