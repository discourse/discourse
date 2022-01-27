# frozen_string_literal: true

require 'rails_helper'

describe Admin::SiteSettingsController do

  it "is a subclass of AdminController" do
    expect(Admin::SiteSettingsController < Admin::AdminController).to eq(true)
  end

  context 'while logged in as an admin' do
    fab!(:admin) { Fabricate(:admin) }

    before do
      sign_in(admin)
    end

    describe '#index' do
      it 'returns valid info' do
        get "/admin/site_settings.json"
        expect(response.status).to eq(200)
        json = response.parsed_body
        expect(json["site_settings"].length).to be > 100

        locale = json["site_settings"].select do |s|
          s["setting"] == "default_locale"
        end

        expect(locale.length).to eq(1)
      end
    end

    describe '#update' do
      before do
        SiteSetting.setting(:test_setting, "default")
        SiteSetting.setting(:test_upload, "", type: :upload)
        SiteSetting.refresh!
      end

      it 'sets the value when the param is present' do
        put "/admin/site_settings/test_setting.json", params: {
          test_setting: 'hello'
        }
        expect(response.status).to eq(200)
        expect(SiteSetting.test_setting).to eq('hello')
      end

      it 'works for deprecated settings' do
        put "/admin/site_settings/search_tokenize_chinese_japanese_korean.json", params: {
          search_tokenize_chinese_japanese_korean: true
        }

        expect(response.status).to eq(200)
        expect(SiteSetting.search_tokenize_chinese).to eq(true)
      end

      it 'allows value to be a blank string' do
        put "/admin/site_settings/test_setting.json", params: {
          test_setting: ''
        }
        expect(response.status).to eq(200)
        expect(SiteSetting.test_setting).to eq('')
      end

      describe 'default user options' do
        let!(:user1) { Fabricate(:user) }
        let!(:user2) { Fabricate(:user) }

        it 'should update all existing user options' do
          SiteSetting.default_email_in_reply_to = true

          user2.user_option.email_in_reply_to = true
          user2.user_option.save!

          put "/admin/site_settings/default_email_in_reply_to.json", params: {
            default_email_in_reply_to: false,
            update_existing_user: true
          }

          user2.reload
          expect(user2.user_option.email_in_reply_to).to eq(false)
        end

        it 'should not update existing user options' do
          expect {
            put "/admin/site_settings/default_email_in_reply_to.json", params: {
              default_email_in_reply_to: false
            }
          }.to change { UserOption.where(email_in_reply_to: false).count }.by(0)
        end

        it 'should update `email_digests` column in existing user options' do
          UserOption.last.update(email_digests: false)

          expect {
            put "/admin/site_settings/default_email_digest_frequency.json", params: {
              default_email_digest_frequency: 30,
              update_existing_user: true
            }
          }.to change { UserOption.where(email_digests: true).count }.by(1)

          expect {
            put "/admin/site_settings/default_email_digest_frequency.json", params: {
              default_email_digest_frequency: 0,
              update_existing_user: true
            }
          }.to change { UserOption.where(email_digests: false).count }.by(User.count)
        end
      end

      describe 'default categories' do
        fab!(:user1) { Fabricate(:user) }
        fab!(:user2) { Fabricate(:user) }
        fab!(:staged_user) { Fabricate(:staged) }
        let(:watching) { NotificationLevels.all[:watching] }
        let(:tracking) { NotificationLevels.all[:tracking] }

        let(:category_ids) { 3.times.collect { Fabricate(:category).id } }

        before do
          SiteSetting.setting(:default_categories_watching, category_ids.first(2).join("|"))
          CategoryUser.create!(category_id: category_ids.last, notification_level: tracking, user: user2)
        end

        after do
          SiteSetting.setting(:default_categories_watching, "")
        end

        it 'should update existing users user preference' do
          put "/admin/site_settings/default_categories_watching.json", params: {
            default_categories_watching: category_ids.last(2).join("|"),
            update_existing_user: true
          }

          expect(response.status).to eq(200)
          expect(CategoryUser.where(category_id: category_ids.first, notification_level: watching).count).to eq(0)
          expect(CategoryUser.where(category_id: category_ids.last, notification_level: watching).count).to eq(User.real.where(staged: false).count - 1)

          topic = Fabricate(:topic, category_id: category_ids.last)
          topic_user1 = Fabricate(:topic_user, topic: topic, notification_level: TopicUser.notification_levels[:watching], notifications_reason_id: TopicUser.notification_reasons[:auto_watch_category])
          topic_user2 = Fabricate(:topic_user, topic: topic, notification_level: TopicUser.notification_levels[:watching], notifications_reason_id: TopicUser.notification_reasons[:user_changed])

          put "/admin/site_settings/default_categories_watching.json", params: {
            default_categories_watching: "",
            update_existing_user: true
          }
          expect(response.status).to eq(200)
          expect(CategoryUser.where(category_id: category_ids, notification_level: watching).count).to eq(0)
          expect(topic_user1.reload.notification_level).to eq(TopicUser.notification_levels[:regular])
          expect(topic_user2.reload.notification_level).to eq(TopicUser.notification_levels[:watching])
        end

        it 'should not update existing users user preference' do
          expect {
            put "/admin/site_settings/default_categories_watching.json", params: {
              default_categories_watching: category_ids.last(2).join("|")
            }
          }.to change { CategoryUser.where(category_id: category_ids.first, notification_level: watching).count }.by(0)

          expect(response.status).to eq(200)
          expect(CategoryUser.where(category_id: category_ids.last, notification_level: watching).count).to eq(0)

          topic = Fabricate(:topic, category_id: category_ids.last)
          topic_user1 = Fabricate(:topic_user, topic: topic, notification_level: TopicUser.notification_levels[:watching], notifications_reason_id: TopicUser.notification_reasons[:auto_watch_category])
          topic_user2 = Fabricate(:topic_user, topic: topic, notification_level: TopicUser.notification_levels[:watching], notifications_reason_id: TopicUser.notification_reasons[:user_changed])
          put "/admin/site_settings/default_categories_watching.json", params: {
            default_categories_watching: "",
          }
          expect(response.status).to eq(200)
          expect(CategoryUser.where(category_id: category_ids.first, notification_level: watching).count).to eq(0)
          expect(topic_user1.reload.notification_level).to eq(TopicUser.notification_levels[:watching])
          expect(topic_user2.reload.notification_level).to eq(TopicUser.notification_levels[:watching])
        end
      end

      describe 'default tags' do
        fab!(:user1) { Fabricate(:user) }
        fab!(:user2) { Fabricate(:user) }
        fab!(:staged_user) { Fabricate(:staged) }
        let(:watching) { NotificationLevels.all[:watching] }
        let(:tracking) { NotificationLevels.all[:tracking] }

        let(:tags) { 3.times.collect { Fabricate(:tag) } }

        before do
          SiteSetting.setting(:default_tags_watching, tags.first(2).pluck(:name).join("|"))
          TagUser.create!(tag_id: tags.last.id, notification_level: tracking, user: user2)
        end

        after do
          SiteSetting.setting(:default_tags_watching, "")
        end

        it 'should update existing users user preference' do
          put "/admin/site_settings/default_tags_watching.json", params: {
            default_tags_watching: tags.last(2).pluck(:name).join("|"),
            update_existing_user: true
          }

          expect(TagUser.where(tag_id: tags.first.id, notification_level: watching).count).to eq(0)
          expect(TagUser.where(tag_id: tags.last.id, notification_level: watching).count).to eq(User.real.where(staged: false).count - 1)
        end

        it 'should not update existing users user preference' do
          expect {
            put "/admin/site_settings/default_tags_watching.json", params: {
              default_tags_watching: tags.last(2).pluck(:name).join("|")
            }
          }.to change { TagUser.where(tag_id: tags.first.id, notification_level: watching).count }.by(0)

          expect(TagUser.where(tag_id: tags.last.id, notification_level: watching).count).to eq(0)
        end
      end

      describe '#user_count' do
        fab!(:user) { Fabricate(:user) }
        fab!(:staged_user) { Fabricate(:staged) }
        let(:tracking) { NotificationLevels.all[:tracking] }

        it 'should return correct user count for default categories change' do
          category_id = Fabricate(:category).id

          put "/admin/site_settings/default_categories_watching/user_count.json", params: {
            default_categories_watching: category_id
          }

          expect(response.parsed_body["user_count"]).to eq(User.real.where(staged: false).count)

          CategoryUser.create!(category_id: category_id, notification_level: tracking, user: user)

          put "/admin/site_settings/default_categories_watching/user_count.json", params: {
            default_categories_watching: category_id
          }

          expect(response.parsed_body["user_count"]).to eq(User.real.where(staged: false).count - 1)

          SiteSetting.setting(:default_categories_watching, "")
        end

        it 'should return correct user count for default tags change' do
          tag = Fabricate(:tag)

          put "/admin/site_settings/default_tags_watching/user_count.json", params: {
            default_tags_watching: tag.name
          }

          expect(response.parsed_body["user_count"]).to eq(User.real.where(staged: false).count)

          TagUser.create!(tag_id: tag.id, notification_level: tracking, user: user)

          put "/admin/site_settings/default_tags_watching/user_count.json", params: {
            default_tags_watching: tag.name
          }

          expect(response.parsed_body["user_count"]).to eq(User.real.where(staged: false).count - 1)

          SiteSetting.setting(:default_tags_watching, "")
        end
      end

      describe 'upload site settings' do
        it 'can remove the site setting' do
          SiteSetting.test_upload = Fabricate(:upload)

          put "/admin/site_settings/test_upload.json", params: {
            test_upload: nil
          }

          expect(response.status).to eq(200)
          expect(SiteSetting.test_upload).to eq(nil)
        end

        it 'can reset the site setting to the default' do
          SiteSetting.test_upload = nil
          default_upload = Upload.find(-1)

          put "/admin/site_settings/test_upload.json", params: {
            test_upload: default_upload.url
          }

          expect(response.status).to eq(200)
          expect(SiteSetting.test_upload).to eq(default_upload)
        end

        it 'can update the site setting' do
          upload = Fabricate(:upload)

          put "/admin/site_settings/test_upload.json", params: {
            test_upload: upload.url
          }

          expect(response.status).to eq(200)
          expect(SiteSetting.test_upload).to eq(upload)

          user_history = UserHistory.last

          expect(user_history.action).to eq(
            UserHistory.actions[:change_site_setting]
          )

          expect(user_history.previous_value).to eq(nil)
          expect(user_history.new_value).to eq(upload.url)
        end
      end

      it 'logs the change' do
        SiteSetting.test_setting = 'previous'

        expect do
          put "/admin/site_settings/test_setting.json", params: {
            test_setting: 'hello'
          }
        end.to change { UserHistory.where(action: UserHistory.actions[:change_site_setting]).count }.by(1)

        expect(response.status).to eq(200)
        expect(SiteSetting.test_setting).to eq('hello')
      end

      it 'does not allow changing of hidden settings' do
        SiteSetting.setting(:hidden_setting, "hidden", hidden: true)
        SiteSetting.refresh!

        put "/admin/site_settings/hidden_setting.json", params: {
          hidden_setting: 'not allowed'
        }

        expect(SiteSetting.hidden_setting).to eq("hidden")
        expect(response.status).to eq(422)
      end

      it 'fails when a setting does not exist' do
        put "/admin/site_settings/provider.json", params: { provider: 'gotcha' }
        expect(response.status).to eq(422)
      end
    end
  end
end
