# frozen_string_literal: true

RSpec.describe TranslationOverride do
  describe "Validations" do
    describe "#value" do
      before do
        I18n.backend.store_translations(
          I18n.locale,
          "user_notifications.user_did_something" => "%{first} %{second}",
        )

        I18n.backend.store_translations(
          :en,
          something: {
            one: "%{key1} %{key2}",
            other: "%{key3} %{key4}",
          },
        )
      end

      describe "when interpolation keys are missing" do
        it "should not be valid" do
          translation_override =
            TranslationOverride.upsert!(I18n.locale, "some_key", "%{key} %{omg}")

          expect(translation_override.errors.full_messages).to include(
            I18n.t(
              "activerecord.errors.models.translation_overrides.attributes.value.invalid_interpolation_keys",
              keys: "key, omg",
              count: 2,
            ),
          )
        end

        context "when custom interpolation keys are included" do
          %w[
            user_notifications.user_did_something
            user_notifications.only_reply_by_email
            user_notifications.only_reply_by_email_pm
            user_notifications.reply_by_email
            user_notifications.reply_by_email_pm
            user_notifications.visit_link_to_respond
            user_notifications.visit_link_to_respond_pm
          ].each do |i18n_key|
            it "should validate keys for #{i18n_key}" do
              interpolation_key_names =
                described_class::ALLOWED_CUSTOM_INTERPOLATION_KEYS.find do |keys, _|
                  keys.include?("user_notifications.user_")
                end

              string_with_interpolation_keys =
                interpolation_key_names.map { |x| "%{#{x}}" }.join(" ")

              translation_override =
                TranslationOverride.upsert!(
                  I18n.locale,
                  i18n_key,
                  "#{string_with_interpolation_keys} %{something}",
                )

              expect(translation_override.errors.full_messages).to include(
                I18n.t(
                  "activerecord.errors.models.translation_overrides.attributes.value.invalid_interpolation_keys",
                  keys: "something",
                  count: 1,
                ),
              )
            end
          end

          it "should validate keys that shouldn't be used outside of user_notifications" do
            I18n.backend.store_translations(:en, "not_a_notification" => "Test %{key1}")
            translation_override =
              TranslationOverride.upsert!(
                I18n.locale,
                "not_a_notification",
                "Overridden %{key1} %{topic_title_url_encoded}",
              )
            expect(translation_override.errors.full_messages).to include(
              I18n.t(
                "activerecord.errors.models.translation_overrides.attributes.value.invalid_interpolation_keys",
                keys: "topic_title_url_encoded",
                count: 1,
              ),
            )
          end
        end
      end

      describe "with valid custom interpolation keys" do
        it "works" do
          translation_override =
            TranslationOverride.upsert!(
              I18n.locale,
              "system_messages.welcome_user.text_body_template",
              "Hello %{name} %{username} %{name_or_username} and welcome to %{site_name}!",
            )

          expect(translation_override.errors).to be_empty
        end
      end

      describe "pluralized keys" do
        describe "valid keys" do
          it "converts zero to other" do
            translation_override =
              TranslationOverride.upsert!(I18n.locale, "something.zero", "%{key3} %{key4} hello")
            expect(translation_override.errors.full_messages).to eq([])
          end

          it "converts two to other" do
            translation_override =
              TranslationOverride.upsert!(I18n.locale, "something.two", "%{key3} %{key4} hello")
            expect(translation_override.errors.full_messages).to eq([])
          end

          it "converts few to other" do
            translation_override =
              TranslationOverride.upsert!(I18n.locale, "something.few", "%{key3} %{key4} hello")
            expect(translation_override.errors.full_messages).to eq([])
          end

          it "converts many to other" do
            translation_override =
              TranslationOverride.upsert!(I18n.locale, "something.many", "%{key3} %{key4} hello")
            expect(translation_override.errors.full_messages).to eq([])
          end
        end

        describe "invalid keys" do
          it "does not transform 'tonz'" do
            translation_override =
              TranslationOverride.upsert!(I18n.locale, "something.tonz", "%{key3} %{key4} hello")
            expect(translation_override.errors.full_messages).to include(
              I18n.t(
                "activerecord.errors.models.translation_overrides.attributes.value.invalid_interpolation_keys",
                keys: "key3, key4",
                count: 2,
              ),
            )
          end
        end
      end
    end
  end

  it "upserts values" do
    TranslationOverride.upsert!("en", "some.key", "some value")

    ovr = TranslationOverride.where(locale: "en", translation_key: "some.key").first
    expect(ovr).to be_present
    expect(ovr.value).to eq("some value")
  end

  it "sanitizes values before upsert" do
    xss = "<a target='blank' href='%{path}'>Click here</a> <script>alert('TEST');</script>"

    TranslationOverride.upsert!("en", "js.themes.error_caused_by", xss)

    ovr =
      TranslationOverride.where(locale: "en", translation_key: "js.themes.error_caused_by").first
    expect(ovr).to be_present
    expect(ovr.value).to eq("<a href=\"%{path}\">Click here</a> alert('TEST');")
  end

  it "stores js for a message format key" do
    TranslationOverride.upsert!(
      "ru",
      "some.key_MF",
      "{NUM_RESULTS, plural, one {1 result} other {many} }",
    )

    ovr = TranslationOverride.where(locale: "ru", translation_key: "some.key_MF").first
    expect(ovr).to be_present
    expect(ovr.compiled_js).to start_with("function")
    expect(ovr.compiled_js).to_not match(/Invalid Format/i)
  end

  describe "site cache" do
    def cached_value(guardian, translation_key, locale:)
      types_name, name_key, attribute = translation_key.split(".")

      I18n.with_locale(locale) do
        json = Site.json_for(guardian)

        JSON.parse(json)[types_name].find { |x| x["name_key"] == name_key }[attribute]
      end
    end

    let!(:anon_guardian) { Guardian.new }
    let!(:user_guardian) { Guardian.new(Fabricate(:user)) }

    shared_examples "resets site text" do
      it "resets the site cache when translations of post_action_types are changed" do
        I18n.locale = :de

        translation_keys.each do |translation_key|
          original_value = I18n.t(translation_key, locale: "en")
          expect(cached_value(user_guardian, translation_key, locale: "en")).to eq(original_value)
          expect(cached_value(anon_guardian, translation_key, locale: "en")).to eq(original_value)

          TranslationOverride.upsert!("en", translation_key, "bar")
          expect(cached_value(user_guardian, translation_key, locale: "en")).to eq("bar")
          expect(cached_value(anon_guardian, translation_key, locale: "en")).to eq("bar")
        end

        TranslationOverride.revert!("en", translation_keys)

        translation_keys.each do |translation_key|
          original_value = I18n.t(translation_key, locale: "en")
          expect(cached_value(user_guardian, translation_key, locale: "en")).to eq(original_value)
          expect(cached_value(anon_guardian, translation_key, locale: "en")).to eq(original_value)
        end
      end
    end

    context "with post_action_types" do
      let(:translation_keys) { ["post_action_types.off_topic.description"] }

      include_examples "resets site text"
    end

    context "with topic_flag_types" do
      let(:translation_keys) { ["topic_flag_types.spam.description"] }

      include_examples "resets site text"
    end

    context "with multiple keys" do
      let(:translation_keys) do
        %w[post_action_types.off_topic.description topic_flag_types.spam.description]
      end

      include_examples "resets site text"
    end

    describe "#reload_all_overrides!" do
      it "correctly reloads all translation overrides" do
        original_en_topics = I18n.t("topics", locale: :en)
        original_en_emoji = I18n.t("js.composer.emoji", locale: :en)
        original_en_offtopic_description =
          I18n.t("post_action_types.off_topic.description", locale: :en)
        original_de_likes = I18n.t("likes", locale: :de)

        TranslationOverride.create!(locale: "en", translation_key: "topics", value: "Threads")
        TranslationOverride.create!(
          locale: "en",
          translation_key: "js.composer.emoji",
          value: "Smilies",
        )
        TranslationOverride.create!(
          locale: "en",
          translation_key: "post_action_types.off_topic.description",
          value: "Overridden description",
        )
        TranslationOverride.create!(
          locale: "de",
          translation_key: "likes",
          value: "„Gefällt mir“-Angaben",
        )

        expect(I18n.t("topics", locale: :en)).to eq(original_en_topics)
        expect(I18n.t("js.composer.emoji", locale: :en)).to eq(original_en_emoji)
        expect(
          cached_value(anon_guardian, "post_action_types.off_topic.description", locale: :en),
        ).to eq(original_en_offtopic_description)
        expect(I18n.t("likes", locale: :de)).to eq(original_de_likes)

        TranslationOverride.reload_all_overrides!

        expect(I18n.t("topics", locale: :en)).to eq("Threads")
        expect(I18n.t("js.composer.emoji", locale: :en)).to eq("Smilies")
        expect(
          cached_value(anon_guardian, "post_action_types.off_topic.description", locale: :en),
        ).to eq("Overridden description")
        expect(I18n.t("likes", locale: :de)).to eq("„Gefällt mir“-Angaben")

        TranslationOverride.revert!(
          :en,
          %w[topics js.composer.emoji post_action_types.off_topic.description],
        )
        TranslationOverride.revert!(:de, ["likes"])
      end
    end
  end
end
