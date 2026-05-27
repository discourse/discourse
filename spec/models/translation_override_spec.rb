# frozen_string_literal: true

RSpec.describe TranslationOverride do
  describe "Validations" do
    describe "#value" do
      before do
        I18n.backend.store_translations(
          I18n.locale,
          { user_notifications: { user_did_something: "%{first} %{second}" } },
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
            TranslationOverride.upsert!(
              I18n.locale,
              "user_notifications.user_did_something",
              "%{key} %{omg}",
            )

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
                described_class.custom_interpolation_keys("user_notifications.user_")

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
            allow_missing_translations do
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

    describe "MessageFormat translations" do
      subject(:override) do
        described_class.new(
          translation_key: "admin_js.admin.user.delete_all_posts_confirm_MF",
          locale: "en",
        )
      end

      it do
        is_expected.to allow_value(
          "This has {COUNT, plural, one{one member} other{# members}}.",
        ).for(:value).against(:base)
      end
      it do
        is_expected.not_to allow_value(
          "This has {COUNT, plural, one{one member} many{# members} other{# members}}.",
        ).for(:value).with_message(/plural case many is not valid/, against: :base)
      end
      it do
        is_expected.not_to allow_value("This has {COUNT, ").for(:value).with_message(
          /invalid syntax/,
          against: :base,
        )
      end
    end
  end

  it "upserts values" do
    I18n.backend.store_translations(:en, { some: { key: "initial value" } })
    TranslationOverride.upsert!("en", "some.key", "some value")

    ovr = TranslationOverride.where(locale: "en", translation_key: "some.key").first
    expect(ovr).to be_present
    expect(ovr.value).to eq("some value")
  end

  it "sanitizes values before upsert" do
    xss = "<a target='_blank' href='%{path}'>Click here</a> <script>alert('TEST');</script>"

    TranslationOverride.upsert!("en", "js.themes.error_caused_by", xss)

    ovr =
      TranslationOverride.where(locale: "en", translation_key: "js.themes.error_caused_by").first
    expect(ovr).to be_present
    expect(ovr.value).to eq("<a target=\"_blank\" href=\"%{path}\">Click here</a> alert('TEST');")
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

  describe "#original_translation_deleted?" do
    context "when the original translation still exists" do
      fab!(:translation) { Fabricate(:translation_override, translation_key: "title") }

      it { expect(translation.original_translation_deleted?).to eq(false) }
    end

    context "when the original translation has been turned into a nested key" do
      fab!(:translation) { Fabricate(:translation_override, translation_key: "title") }

      before { translation.update_attribute("translation_key", "dates") }

      it { expect(translation.original_translation_deleted?).to eq(true) }
    end

    context "when the original translation no longer exists" do
      fab!(:translation) do
        allow_missing_translations { Fabricate(:translation_override, translation_key: "foo.bar") }
      end

      it { expect(translation.original_translation_deleted?).to eq(true) }
    end
  end

  describe "#original_translation_updated?" do
    context "when the translation is up to date" do
      fab!(:translation) { Fabricate(:translation_override, translation_key: "title") }

      it { expect(translation.original_translation_updated?).to eq(false) }
    end

    context "when the translation is outdated" do
      fab!(:translation) do
        Fabricate(:translation_override, translation_key: "title", original_translation: "outdated")
      end

      it { expect(translation.original_translation_updated?).to eq(true) }
    end

    context "when we can't tell because the translation is too old" do
      fab!(:translation) do
        Fabricate(:translation_override, translation_key: "title", original_translation: nil)
      end

      it { expect(translation.original_translation_updated?).to eq(false) }
    end
  end

  describe "#invalid_interpolation_keys" do
    fab!(:translation) do
      Fabricate(
        :translation_override,
        translation_key: "system_messages.welcome_user.subject_template",
      )
    end

    it "picks out invalid keys and ignores known and custom keys" do
      translation.update_attribute("value", "Hello, %{name}! Welcome to %{site_name}. %{foo}")

      expect(translation.invalid_interpolation_keys).to contain_exactly("foo")
    end
  end

  describe "#refresh_status" do
    context "when fixing a translation with invalid interpolation keys" do
      fab!(:translation) do
        Fabricate(
          :translation_override,
          translation_key: "system_messages.welcome_user.subject_template",
          status: "invalid_interpolation_keys",
        )
      end

      before do
        translation.update_attribute("value", "Hello, %{name}! Welcome to %{site_name}. %{foo}")
      end

      it "refreshes to status to up to date" do
        expect {
          translation.update_attribute("value", "Hello, %{name}! Welcome to %{site_name}.")
        }.to change { translation.status }.from("invalid_interpolation_keys").to("up_to_date")
      end
    end

    context "when updating a translation that has had the original updated" do
      fab!(:translation) do
        Fabricate(
          :translation_override,
          translation_key: "title",
          original_translation: "outdated",
          status: "outdated",
        )
      end

      it "refreshes to status to up to date" do
        expect { translation.update_attribute("value", "Discourse") }.to change {
          translation.status
        }.from("outdated").to("up_to_date")
      end
    end
  end

  describe "#message_format?" do
    subject(:override) { described_class.new(translation_key: key) }

    context "when override is for a MessageFormat translation" do
      let(:key) { "admin_js.admin.user.delete_all_posts_confirm_MF" }

      it { is_expected.to be_a_message_format }
    end

    context "when override is not for a MessageFormat translation" do
      let(:key) { "admin_js.type_to_filter" }

      it { is_expected.not_to be_a_message_format }
    end
  end

  describe "#make_up_to_date!" do
    fab!(:override) { Fabricate(:translation_override, translation_key: "js.posts_likes_MF") }

    context "when override is not outdated" do
      it "does nothing" do
        expect { override.make_up_to_date! }.not_to change { override.reload.attributes }
      end

      it "returns a falsy value" do
        expect(override.make_up_to_date!).to be_falsy
      end
    end

    context "when override is outdated" do
      before { override.update_columns(status: :outdated, value: "{ Invalid MF syntax") }

      it "updates its original translation to match the current default" do
        expect { override.make_up_to_date! }.to change { override.reload.original_translation }.to(
          I18n.overrides_disabled { I18n.t("js.posts_likes_MF") },
        )
      end

      it "sets its status to 'up_to_date'" do
        expect { override.make_up_to_date! }.to change { override.reload.up_to_date? }.to(true)
      end

      it "returns a truthy value" do
        expect(override.make_up_to_date!).to be_truthy
      end
    end
  end
end
