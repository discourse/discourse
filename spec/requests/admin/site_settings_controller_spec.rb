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
        json = ::JSON.parse(response.body)
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
          user2.user_option.email_in_reply_to = false
          user2.user_option.save!

          expect {
            put "/admin/site_settings/default_email_in_reply_to.json", params: {
              default_email_in_reply_to: false,
              updateExistingUsers: true
            }
          }.to change { UserOption.where(email_in_reply_to: false).count }.by(User.count - 1)
        end

        it 'should not update existing user options' do
          expect {
            put "/admin/site_settings/default_email_in_reply_to.json", params: {
              default_email_in_reply_to: false
            }
          }.to change { UserOption.where(email_in_reply_to: false).count }.by(0)
        end

        it 'should disable email digests in existing user options' do
          expect {
            put "/admin/site_settings/default_email_digest_frequency.json", params: {
              default_email_digest_frequency: 0,
              updateExistingUsers: true
            }
          }.to change { UserOption.where(email_digests: false).count }.by(User.count)
        end
      end

      describe 'default categories' do
        let(:user1) { Fabricate(:user) }
        let(:user2) { Fabricate(:user) }
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
            updateExistingUsers: true
          }

          expect(CategoryUser.where(category_id: category_ids.first, notification_level: watching).count).to eq(0)
          expect(CategoryUser.where(category_id: category_ids.last, notification_level: watching).count).to eq(User.count - 1)
        end

        it 'should not update existing users user preference' do
          expect {
            put "/admin/site_settings/default_categories_watching.json", params: {
              default_categories_watching: category_ids.last(2).join("|")
            }
          }.to change { CategoryUser.where(category_id: category_ids.first, notification_level: watching).count }.by(0)

          expect(CategoryUser.where(category_id: category_ids.last, notification_level: watching).count).to eq(0)
        end
      end

      describe 'default tags' do
        let(:user1) { Fabricate(:user) }
        let(:user2) { Fabricate(:user) }
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
            updateExistingUsers: true
          }

          expect(TagUser.where(tag_id: tags.first.id, notification_level: watching).count).to eq(0)
          expect(TagUser.where(tag_id: tags.last.id, notification_level: watching).count).to eq(User.count - 1)
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
        let(:user) { Fabricate(:user) }
        let(:tracking) { NotificationLevels.all[:tracking] }

        it 'should return correct user count for default categories change' do
          category_id = Fabricate(:category).id

          put "/admin/site_settings/default_categories_watching/user_count.json", params: {
            default_categories_watching: category_id
          }

          expect(JSON.parse(response.body)["user_count"]).to eq(User.count)

          CategoryUser.create!(category_id: category_id, notification_level: tracking, user: user)

          put "/admin/site_settings/default_categories_watching/user_count.json", params: {
            default_categories_watching: category_id
          }

          expect(JSON.parse(response.body)["user_count"]).to eq(User.count - 1)

          SiteSetting.setting(:default_categories_watching, "")
        end

        it 'should return correct user count for default tags change' do
          tag = Fabricate(:tag)

          put "/admin/site_settings/default_tags_watching/user_count.json", params: {
            default_tags_watching: tag.name
          }

          expect(JSON.parse(response.body)["user_count"]).to eq(User.count)

          TagUser.create!(tag_id: tag.id, notification_level: tracking, user: user)

          put "/admin/site_settings/default_tags_watching/user_count.json", params: {
            default_tags_watching: tag.name
          }

          expect(JSON.parse(response.body)["user_count"]).to eq(User.count - 1)

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
