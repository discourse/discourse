# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Admin::SiteTextsController do
  fab!(:admin) { Fabricate(:admin) }
  fab!(:user) { Fabricate(:user) }
  let(:default_locale) { I18n.locale }

  after do
    TranslationOverride.delete_all
    I18n.reload!
  end

  it "is a subclass of AdminController" do
    expect(Admin::SiteTextsController < Admin::AdminController).to eq(true)
  end

  context "when not logged in as an admin" do
    it "raises an error if you aren't logged in" do
      put '/admin/customize/site_texts/some_key.json', params: {
        site_text: { value: 'foo' }, locale: default_locale
      }

      expect(response.status).to eq(404)
    end

    it "raises an error if you aren't an admin" do
      sign_in(user)

      put "/admin/customize/site_texts/some_key.json", params: {
        site_text: { value: 'foo' }, locale: default_locale
      }
      expect(response.status).to eq(404)

      put "/admin/customize/reseed.json", params: {
        category_ids: [], topic_ids: []
      }
      expect(response.status).to eq(404)
    end
  end

  context "when logged in as admin" do
    before do
      sign_in(admin)
    end

    describe '#index' do
      it 'returns json' do
        get "/admin/customize/site_texts.json", params: { q: 'title', locale: default_locale }
        expect(response.status).to eq(200)
        expect(response.parsed_body['site_texts']).to include(include("id" => "title"))
      end

      it 'sets has_more to true if more than 50 results were found' do
        get "/admin/customize/site_texts.json", params: { q: 'e', locale: default_locale }
        expect(response.status).to eq(200)
        expect(response.parsed_body['site_texts'].size).to eq(50)
        expect(response.parsed_body['extras']['has_more']).to be_truthy
      end

      it 'works with pages' do
        texts = Set.new

        get "/admin/customize/site_texts.json", params: { q: 'e', locale: default_locale }
        response.parsed_body['site_texts'].each { |text| texts << text['id'] }
        expect(texts.size).to eq(50)

        get "/admin/customize/site_texts.json", params: { q: 'e', page: 1, locale: default_locale }
        response.parsed_body['site_texts'].each { |text| texts << text['id'] }
        expect(texts.size).to eq(100)
      end

      it 'works with locales' do
        get "/admin/customize/site_texts.json", params: { q: 'yes_value', locale: default_locale }
        value = response.parsed_body['site_texts'].find { |text| text['id'] == 'js.yes_value' }['value']
        expect(value).to eq(I18n.t('js.yes_value', locale: default_locale))

        get "/admin/customize/site_texts.json", params: { q: 'yes_value', locale: 'de' }
        value = response.parsed_body['site_texts'].find { |text| text['id'] == 'js.yes_value' }['value']
        expect(value).to eq(I18n.t('js.yes_value', locale: :de))
      end

      it 'returns an error on invalid locale' do
        get "/admin/customize/site_texts.json", params: { locale: '?' }
        expect(response.status).to eq(400)
      end

      it 'returns an error on empty locale' do
        get "/admin/customize/site_texts.json"
        expect(response.status).to eq(400)
      end

      it 'normalizes quotes during search' do
        value = %q|“That’s a ‘magic’ sock.”|
        put "/admin/customize/site_texts/title.json", params: { site_text: { value: value, locale: default_locale } }

        [
          %q|That's a 'magic' sock.|,
          %q|That’s a ‘magic’ sock.|,
          %q|“That's a 'magic' sock.”|,
          %q|"That's a 'magic' sock."|,
          %q|«That's a 'magic' sock.»|,
          %q|„That’s a ‚magic‘ sock.“|
        ].each do |search_term|
          get "/admin/customize/site_texts.json", params: { q: search_term, locale: default_locale }
          expect(response.status).to eq(200)
          expect(response.parsed_body['site_texts']).to include(include("id" => "title", "value" => value))
        end
      end

      it 'normalizes ellipsis' do
        value = "Loading Discussion…"
        put "/admin/customize/site_texts/embed.loading.json", params: { site_text: { value: value, locale: default_locale } }

        [
          "Loading Discussion",
          "Loading Discussion...",
          "Loading Discussion…"
        ].each do |search_term|
          get "/admin/customize/site_texts.json", params: { q: search_term, locale: default_locale }
          expect(response.status).to eq(200)
          expect(response.parsed_body['site_texts']).to include(include("id" => "embed.loading", "value" => value))
        end
      end

      it 'does not return overrides for keys that do not exist in English' do
        SiteSetting.default_locale = :ru
        TranslationOverride.create!(locale: :ru, translation_key: 'missing_plural_key.one', value: 'ONE')
        TranslationOverride.create!(locale: :ru, translation_key: 'another_missing_key', value: 'foo')

        get "/admin/customize/site_texts.json", params: { q: 'missing_plural_key', locale: default_locale }
        expect(response.status).to eq(200)
        expect(response.parsed_body['site_texts']).to be_empty

        get "/admin/customize/site_texts.json", params: { q: 'another_missing_key', locale: default_locale }
        expect(response.status).to eq(200)
        expect(response.parsed_body['site_texts']).to be_empty
      end

      it "returns site text from fallback locale if current locale doesn't have a translation" do
        TranslationOverride.upsert!(:en, 'js.summary.description_time_MF', 'description_time_MF override')
        TranslationOverride.upsert!(:en, 'education.new-topic', 'education.new-topic override')

        get "/admin/customize/site_texts.json", params: { q: 'js.summary.description_time_MF', locale: 'en_GB' }
        expect(response.status).to eq(200)
        value = response.parsed_body['site_texts'].find { |text| text['id'] == 'js.summary.description_time_MF' }['value']
        expect(value).to eq('description_time_MF override')

        get "/admin/customize/site_texts.json", params: { q: 'education.new-topic', locale: 'en_GB' }
        expect(response.status).to eq(200)
        value = response.parsed_body['site_texts'].find { |text| text['id'] == 'education.new-topic' }['value']
        expect(value).to eq('education.new-topic override')
      end

      it "returns only overridden translations" do
        TranslationOverride.upsert!(:en, 'education.new-topic', 'education.new-topic override')

        get "/admin/customize/site_texts.json", params: { locale: 'en', overridden: true }
        expect(response.status).to eq(200)

        site_texts = response.parsed_body['site_texts']
        expect(site_texts.size).to eq(1)

        value = site_texts.find { |text| text['id'] == 'education.new-topic' }['value']
        expect(value).to eq('education.new-topic override')
      end

      context 'plural keys' do
        before do
          I18n.backend.store_translations(:en, colour: { one: '%{count} colour', other: '%{count} colours' })
        end

        shared_examples 'finds correct plural keys' do
          it 'finds the correct plural keys for the locale' do
            SiteSetting.default_locale = locale

            get '/admin/customize/site_texts.json', params: { q: 'colour', locale: locale }
            expect(response.status).to eq(200)

            json = ::JSON.parse(response.body, symbolize_names: true)
            expect(json).to be_present

            site_texts = json[:site_texts]
            expect(site_texts).to be_present

            expected_search_result = expected_translations.map do |key, value|
              overridden = defined?(expected_overridden) ? expected_overridden[key] || false : false
              { id: "colour.#{key}", value: value, can_revert: overridden, overridden: overridden }
            end

            expect(site_texts).to match_array(expected_search_result)
          end
        end

        context 'English' do
          let(:locale) { :en }
          let(:expected_translations) { { one: '%{count} colour', other: '%{count} colours' } }

          include_examples 'finds correct plural keys'
        end

        context 'language with different plural keys and missing translations' do
          let(:locale) { :ru }
          let(:expected_translations) { { one: '%{count} colour', few: '%{count} colours', other: '%{count} colours' } }

          include_examples 'finds correct plural keys'
        end

        context 'language with different plural keys and partial translation' do
          before do
            I18n.backend.store_translations(:ru, colour: { few: '%{count} цвета', many: '%{count} цветов' })
          end

          let(:locale) { :ru }
          let(:expected_translations) { { one: '%{count} colour', few: '%{count} цвета', other: '%{count} colours' } }

          include_examples 'finds correct plural keys'
        end

        context 'with overridden translation not in original translation' do
          before do
            I18n.backend.store_translations(:ru, colour: { few: '%{count} цвета', many: '%{count} цветов' })
            TranslationOverride.create!(locale: :ru, translation_key: 'colour.one', value: 'ONE')
            TranslationOverride.create!(locale: :ru, translation_key: 'colour.few', value: 'FEW')
          end

          let(:locale) { :ru }
          let(:expected_translations) { { one: 'ONE', few: 'FEW', other: '%{count} colours' } }
          let(:expected_overridden) { { one: true, few: true } }

          include_examples 'finds correct plural keys'
        end
      end
    end

    describe '#show' do
      it 'returns a site text for a key that exists' do
        get "/admin/customize/site_texts/js.topic.list.json", params: { locale: default_locale }
        expect(response.status).to eq(200)

        json = response.parsed_body

        site_text = json['site_text']

        expect(site_text['id']).to eq('js.topic.list')
        expect(site_text['value']).to eq(I18n.t("js.topic.list"))
      end

      it 'returns a site text for a key with ampersand' do
        get "/admin/customize/site_texts/js.emoji_picker.food_&_drink.json", params: { locale: default_locale }
        expect(response.status).to eq(200)

        json = response.parsed_body

        site_text = json['site_text']

        expect(site_text['id']).to eq('js.emoji_picker.food_&_drink')
        expect(site_text['value']).to eq(I18n.t("js.emoji_picker.food_&_drink"))
      end

      it 'returns not found for missing keys' do
        get "/admin/customize/site_texts/made_up_no_key_exists.json", params: { locale: default_locale }
        expect(response.status).to eq(404)
      end

      it 'returns overridden = true if there is a translation_overrides record for the key' do
        key = 'js.topic.list'
        put "/admin/customize/site_texts/#{key}.json", params: {
          site_text: { value: I18n.t(key, locale: default_locale), locale: default_locale }
        }
        expect(response.status).to eq(200)

        get "/admin/customize/site_texts/#{key}.json", params: { locale: default_locale }
        expect(response.status).to eq(200)
        json = response.parsed_body
        expect(json['site_text']['overridden']).to eq(true)

        TranslationOverride.destroy_all

        get "/admin/customize/site_texts/#{key}.json", params: { locale: default_locale }
        expect(response.status).to eq(200)
        json = response.parsed_body
        expect(json['site_text']['overridden']).to eq(false)
      end

      it 'returns a site text in the given locale' do
        get "/admin/customize/site_texts/js.topic.list.json", params: { locale: 'es' }
        expect(response.status).to eq(200)

        json = response.parsed_body
        site_text = json['site_text']

        expect(site_text['id']).to eq('js.topic.list')
        expect(site_text['value']).to eq(I18n.t("js.topic.list", locale: :es))
      end

      it 'fails if locale is not given' do
        get "/admin/customize/site_texts/js.topic.list.json"
        expect(response.status).to eq(400)
      end

      it "returns site text from fallback locale if current locale doesn't have a translation" do
        TranslationOverride.upsert!(:en, 'js.summary.description_time_MF', 'description_time_MF override')
        TranslationOverride.upsert!(:en, 'education.new-topic', 'education.new-topic override')

        get "/admin/customize/site_texts/js.summary.description_time_MF.json", params: { locale: 'en_GB' }
        expect(response.status).to eq(200)

        json = response.parsed_body
        site_text = json['site_text']

        expect(site_text['id']).to eq('js.summary.description_time_MF')
        expect(site_text['value']).to eq('description_time_MF override')

        get "/admin/customize/site_texts/education.new-topic.json", params: { locale: 'en_GB' }
        expect(response.status).to eq(200)

        json = response.parsed_body
        site_text = json['site_text']

        expect(site_text['id']).to eq('education.new-topic')
        expect(site_text['value']).to eq('education.new-topic override')
      end

      context 'plural keys' do
        before do
          I18n.backend.store_translations(:en, colour: { one: '%{count} colour', other: '%{count} colours' })
        end

        shared_examples 'has correct plural keys' do
          it 'returns the correct plural keys for the locale' do
            expected_translations.each do |key, value|
              id = "colour.#{key}"

              get "/admin/customize/site_texts/#{id}.json", params: { locale: locale }
              expect(response.status).to eq(200)

              json = response.parsed_body
              expect(json).to be_present

              site_text = json['site_text']
              expect(site_text).to be_present

              expect(site_text['id']).to eq(id)
              expect(site_text['value']).to eq(value)
            end
          end
        end

        context 'English' do
          let(:locale) { :en }
          let(:expected_translations) { { one: '%{count} colour', other: '%{count} colours' } }

          include_examples 'has correct plural keys'
        end

        context 'language with different plural keys and missing translations' do
          let(:locale) { :ru }
          let(:expected_translations) { { one: '%{count} colour', few: '%{count} colours', other: '%{count} colours' } }

          include_examples 'has correct plural keys'
        end

        context 'language with different plural keys and partial translation' do
          before do
            I18n.backend.store_translations(:ru, colour: { few: '%{count} цвета' })
          end

          let(:locale) { :ru }
          let(:expected_translations) { { one: '%{count} colour', few: '%{count} цвета', other: '%{count} colours' } }

          include_examples 'has correct plural keys'
        end
      end
    end

    describe '#update & #revert' do
      it "returns 'not found' when an unknown key is used" do
        put '/admin/customize/site_texts/some_key.json', params: {
          site_text: { value: 'foo', locale: default_locale }
        }

        expect(response.status).to eq(404)

        json = response.parsed_body
        expect(json['error_type']).to eq('not_found')
      end

      it "works as expected with correct keys" do
        put '/admin/customize/site_texts/js.emoji_picker.animals_%26_nature.json', params: {
          site_text: { value: 'foo', locale: default_locale }
        }

        expect(response.status).to eq(200)

        json = response.parsed_body
        site_text = json['site_text']

        expect(site_text['id']).to eq('js.emoji_picker.animals_&_nature')
        expect(site_text['value']).to eq('foo')
      end

      it "does not update restricted keys" do
        put '/admin/customize/site_texts/user_notifications.confirm_old_email.title.json', params: {
          site_text: { value: 'foo', locale: default_locale }
        }

        expect(response.status).to eq(403)

        json = response.parsed_body
        expect(json['error_type']).to eq('invalid_access')
        expect(json['errors'].size).to eq(1)
        expect(json['errors'].first).to eq(I18n.t('email_template_cant_be_modified'))
      end

      it "returns the right error message" do
        I18n.backend.store_translations(SiteSetting.default_locale, some_key: '%{first} %{second}')

        put "/admin/customize/site_texts/some_key.json", params: {
          site_text: { value: 'hello %{key} %{omg}', locale: default_locale }
        }

        expect(response.status).to eq(422)

        body = response.parsed_body

        expect(body['message']).to eq(I18n.t(
          'activerecord.errors.models.translation_overrides.attributes.value.invalid_interpolation_keys',
          keys: 'key, omg'
        ))
      end

      it 'logs the change' do
        original_title = I18n.t(:title)

        put "/admin/customize/site_texts/title.json", params: {
          site_text: { value: 'yay', locale: default_locale }
        }
        expect(response.status).to eq(200)

        log = UserHistory.last

        expect(log.previous_value).to eq(original_title)
        expect(log.new_value).to eq('yay')
        expect(log.action).to eq(UserHistory.actions[:change_site_text])

        delete "/admin/customize/site_texts/title.json", params: { locale: default_locale }
        expect(response.status).to eq(200)

        log = UserHistory.last

        expect(log.previous_value).to eq('yay')
        expect(log.new_value).to eq(original_title)
        expect(log.action).to eq(UserHistory.actions[:change_site_text])
      end

      it 'updates and reverts the key' do
        orig_title = I18n.t(:title)

        put "/admin/customize/site_texts/title.json", params: { site_text: { value: 'hello', locale: default_locale } }
        expect(response.status).to eq(200)

        json = response.parsed_body

        site_text = json['site_text']

        expect(site_text['id']).to eq('title')
        expect(site_text['value']).to eq('hello')

        # Revert
        delete "/admin/customize/site_texts/title.json", params: { locale: default_locale }
        expect(response.status).to eq(200)

        json = response.parsed_body

        site_text = json['site_text']

        expect(site_text['id']).to eq('title')
        expect(site_text['value']).to eq(orig_title)
      end

      it 'returns site texts for the correct locale' do
        locale = :ru

        ru_title = 'title ru'
        ru_mf_text = 'ru {NUM_RESULTS, plural, one {1 result} other {many} }'

        put "/admin/customize/site_texts/title.json", params: { site_text: { value: ru_title, locale: locale } }
        expect(response.status).to eq(200)
        put "/admin/customize/site_texts/js.topic.read_more_MF.json", params: { site_text: { value: ru_mf_text, locale: locale } }
        expect(response.status).to eq(200)

        get "/admin/customize/site_texts/title.json", params: { locale: locale }
        expect(response.status).to eq(200)
        json = response.parsed_body
        expect(json['site_text']['value']).to eq(ru_title)

        get "/admin/customize/site_texts/js.topic.read_more_MF.json", params: { locale: locale }
        expect(response.status).to eq(200)
        json = response.parsed_body
        expect(json['site_text']['value']).to eq(ru_mf_text)

        en_locale = :en

        get "/admin/customize/site_texts/title.json", params: { locale: en_locale }
        expect(response.status).to eq(200)
        json = response.parsed_body
        expect(json['site_text']['value']).to_not eq(ru_title)

        get "/admin/customize/site_texts/js.topic.read_more_MF.json", params: { locale: en_locale }
        expect(response.status).to eq(200)
        json = response.parsed_body
        expect(json['site_text']['value']).to_not eq(ru_mf_text)
      end

      context 'when updating a translation override for a system badge' do
        fab!(:user_with_badge_title) { Fabricate(:active_user) }
        let(:badge) { Badge.find(Badge::Regular) }

        before do
          BadgeGranter.grant(badge, user_with_badge_title)
          user_with_badge_title.update(title: 'Regular')
        end

        it 'updates matching user titles to the override text in a job' do
          expect_enqueued_with(job: :bulk_user_title_update, args: {
            new_title: 'Terminator',
            granted_badge_id: badge.id,
            action: Jobs::BulkUserTitleUpdate::UPDATE_ACTION
          }) do
            put '/admin/customize/site_texts/badges.regular.name.json', params: {
              site_text: { value: 'Terminator', locale: default_locale }
            }
          end

          # Revert
          expect_enqueued_with(job: :bulk_user_title_update, args: {
            granted_badge_id: badge.id,
            action: Jobs::BulkUserTitleUpdate::RESET_ACTION
          }) do
            delete "/admin/customize/site_texts/badges.regular.name.json", params: { locale: default_locale }
          end
        end

        it 'does not update matching user titles when overriding non-title badge text' do
          expect_not_enqueued_with(job: :bulk_user_title_update) do
            put '/admin/customize/site_texts/badges.regular.long_description.json', params: {
              site_text: { value: 'Terminator', locale: default_locale }
            }
          end
        end
      end
    end

    context "reseeding" do
      before do
        staff_category = Fabricate(
          :category,
          name: "Staff EN",
          user: Discourse.system_user
        )
        SiteSetting.staff_category_id = staff_category.id

        guidelines_topic = Fabricate(
          :topic,
          title: "The English Guidelines",
          category: @staff_category,
          user: Discourse.system_user
        )
        Fabricate(:post, topic: guidelines_topic, user: Discourse.system_user)
        SiteSetting.guidelines_topic_id = guidelines_topic.id
      end

      describe '#get_reseed_options' do
        it 'returns correct json' do
          get "/admin/customize/reseed.json"
          expect(response.status).to eq(200)

          expected_reseed_options = {
            categories: [
              { id: "uncategorized_category_id", name: I18n.t("uncategorized_category_name"), selected: true },
              { id: "staff_category_id", name: "Staff EN", selected: true }
            ],
            topics: [{ id: "guidelines_topic_id", name: "The English Guidelines", selected: true }]
          }

          expect(JSON.parse(response.body, symbolize_names: true)).to eq(expected_reseed_options)
        end
      end

      describe '#reseed' do
        it 'reseeds categories and topics' do
          SiteSetting.default_locale = :de

          post "/admin/customize/reseed.json", params: {
            category_ids: ["staff_category_id"],
            topic_ids: ["guidelines_topic_id"]
          }
          expect(response.status).to eq(200)

          expect(Category.find(SiteSetting.staff_category_id).name).to eq(I18n.t("staff_category_name", locale: :de))
          expect(Topic.find(SiteSetting.guidelines_topic_id).title).to eq(I18n.t("guidelines_topic.title", locale: :de))
        end
      end
    end
  end
end
