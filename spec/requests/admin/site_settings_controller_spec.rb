# frozen_string_literal: true

RSpec.describe Admin::SiteSettingsController do
  fab!(:admin) { Fabricate(:admin) }
  fab!(:moderator) { Fabricate(:moderator) }
  fab!(:user) { Fabricate(:user) }

  describe "#index" do
    context "when logged in as an admin" do
      before { sign_in(admin) }

      it "returns valid info" do
        get "/admin/site_settings.json"

        expect(response.status).to eq(200)
        json = response.parsed_body
        expect(json["site_settings"].length).to be > 100

        locale = json["site_settings"].select { |s| s["setting"] == "default_locale" }

        expect(locale.length).to eq(1)
      end
    end

    shared_examples "site settings inaccessible" do
      it "denies access with a 404 response" do
        get "/admin/site_settings.json"

        expect(response.status).to eq(404)
        expect(response.parsed_body["errors"]).to include(I18n.t("not_found"))
      end
    end

    context "when logged in as a moderator" do
      before { sign_in(moderator) }

      include_examples "site settings inaccessible"
    end

    context "when logged in as a non-staff user" do
      before { sign_in(user) }

      include_examples "site settings inaccessible"
    end
  end

  describe "#user_count" do
    fab!(:staged_user) { Fabricate(:staged) }
    let(:tracking) { NotificationLevels.all[:tracking] }

    before do
      SiteSetting.setting(:test_setting, "default")
      SiteSetting.setting(:test_upload, "", type: :upload)
      SiteSetting.refresh!
    end

    context "when logged in as an admin" do
      before { sign_in(admin) }

      it "should return correct user count for default categories change" do
        category_id = Fabricate(:category).id

        put "/admin/site_settings/default_categories_watching/user_count.json",
            params: {
              default_categories_watching: category_id,
            }

        expect(response.parsed_body["user_count"]).to eq(User.real.where(staged: false).count)

        CategoryUser.create!(category_id: category_id, notification_level: tracking, user: user)

        put "/admin/site_settings/default_categories_watching/user_count.json",
            params: {
              default_categories_watching: category_id,
            }

        expect(response.parsed_body["user_count"]).to eq(User.real.where(staged: false).count - 1)

        SiteSetting.setting(:default_categories_watching, "")
      end

      it "should return correct user count for default tags change" do
        tag = Fabricate(:tag)

        put "/admin/site_settings/default_tags_watching/user_count.json",
            params: {
              default_tags_watching: tag.name,
            }

        expect(response.parsed_body["user_count"]).to eq(User.real.where(staged: false).count)

        TagUser.create!(tag_id: tag.id, notification_level: tracking, user: user)

        put "/admin/site_settings/default_tags_watching/user_count.json",
            params: {
              default_tags_watching: tag.name,
            }

        expect(response.parsed_body["user_count"]).to eq(User.real.where(staged: false).count - 1)

        SiteSetting.setting(:default_tags_watching, "")
      end

      it "should return correct user count for user tips" do
        # Disabled user tips
        admin.user_option.update!(seen_popups: [-1])

        # Dismissed each user tip individually
        moderator.user_option.update!(seen_popups: User.user_tips.values)

        # Dismissed just one user tip, but has many posts
        user.user_option.update!(seen_popups: [User.user_tips[:first_notification]])
        user.user_stat.update!(post_count: 100)

        put "/admin/site_settings/enable_user_tips/user_count.json",
            params: {
              enable_user_tips: "true",
            }

        expect(response.status).to eq(200)
        expect(response.parsed_body["user_count"]).to eq(1)

        put "/admin/site_settings/enable_user_tips/user_count.json",
            params: {
              enable_user_tips: "false",
            }

        expect(response.status).to eq(200)
        expect(response.parsed_body["user_count"]).to eq(0)
      end

      context "for sidebar defaults" do
        it "returns the right count for the default_sidebar_categories site setting" do
          category = Fabricate(:category)

          put "/admin/site_settings/default_sidebar_categories/user_count.json",
              params: {
                default_sidebar_categories: "#{category.id}",
              }

          expect(response.status).to eq(200)
          expect(response.parsed_body["user_count"]).to eq(User.real.not_staged.count)
        end

        it "returns the right count for the default_sidebar_tags site setting" do
          tag = Fabricate(:tag)

          put "/admin/site_settings/default_sidebar_tags/user_count.json",
              params: {
                default_sidebar_tags: "#{tag.name}",
              }

          expect(response.status).to eq(200)
          expect(response.parsed_body["user_count"]).to eq(User.real.not_staged.count)
        end
      end

      context "with user options" do
        def expect_user_count(
          site_setting_name:,
          user_setting_name:,
          current_site_setting_value:,
          new_site_setting_value:,
          current_user_setting_value: nil,
          new_user_setting_value: nil
        )
          current_user_setting_value ||= current_site_setting_value
          new_user_setting_value ||= new_site_setting_value

          SiteSetting.public_send("#{site_setting_name}=", current_site_setting_value)
          UserOption.human_users.update_all(user_setting_name => current_user_setting_value)
          user_count = User.human_users.count

          # Correctly counts users when all of them have default value
          put "/admin/site_settings/#{site_setting_name}/user_count.json",
              params: {
                site_setting_name => new_site_setting_value,
              }
          expect(response.parsed_body["user_count"]).to eq(user_count)

          # Correctly counts users when one of them already has new value
          user.user_option.update!(user_setting_name => new_user_setting_value)
          put "/admin/site_settings/#{site_setting_name}/user_count.json",
              params: {
                site_setting_name => new_site_setting_value,
              }
          expect(response.parsed_body["user_count"]).to eq(user_count - 1)

          # Correctly counts users when site setting value has been changed
          SiteSetting.public_send("#{site_setting_name}=", new_site_setting_value)
          put "/admin/site_settings/#{site_setting_name}/user_count.json",
              params: {
                site_setting_name => current_site_setting_value,
              }
          expect(response.parsed_body["user_count"]).to eq(1)
        end

        it "should return correct user count for boolean setting" do
          expect_user_count(
            site_setting_name: "default_other_external_links_in_new_tab",
            user_setting_name: "external_links_in_new_tab",
            current_site_setting_value: false,
            new_site_setting_value: true,
          )
        end

        it "should return correct user count for 'text_size_key'" do
          expect_user_count(
            site_setting_name: "default_text_size",
            user_setting_name: "text_size_key",
            current_site_setting_value: "normal",
            new_site_setting_value: "larger",
            current_user_setting_value: UserOption.text_sizes[:normal],
            new_user_setting_value: UserOption.text_sizes[:larger],
          )
        end

        it "should return correct user count for 'title_count_mode_key'" do
          expect_user_count(
            site_setting_name: "default_title_count_mode",
            user_setting_name: "title_count_mode_key",
            current_site_setting_value: "notifications",
            new_site_setting_value: "contextual",
            current_user_setting_value: UserOption.title_count_modes[:notifications],
            new_user_setting_value: UserOption.title_count_modes[:contextual],
          )
        end
      end
    end

    shared_examples "user counts inaccessible" do
      it "denies access with a 404 response" do
        category_id = Fabricate(:category).id

        put "/admin/site_settings/default_categories_watching/user_count.json",
            params: {
              default_categories_watching: category_id,
            }

        expect(response.status).to eq(404)
        expect(response.parsed_body["errors"]).to include(I18n.t("not_found"))
      end
    end

    context "when logged in as a moderator" do
      before { sign_in(moderator) }

      include_examples "user counts inaccessible"
    end

    context "when logged in as a non-staff user" do
      before { sign_in(user) }

      include_examples "user counts inaccessible"
    end
  end

  describe "#update" do
    before do
      SiteSetting.setting(:test_setting, "default")
      SiteSetting.setting(:test_upload, "", type: :upload)
      SiteSetting.refresh!
    end

    context "when logged in as an admin" do
      before { sign_in(admin) }

      it "sets the value when the param is present" do
        put "/admin/site_settings/test_setting.json", params: { test_setting: "hello" }
        expect(response.status).to eq(200)
        expect(SiteSetting.test_setting).to eq("hello")
      end

      it "works for deprecated settings" do
        put "/admin/site_settings/search_tokenize_chinese_japanese_korean.json",
            params: {
              search_tokenize_chinese_japanese_korean: true,
            }

        expect(response.status).to eq(200)
        expect(SiteSetting.search_tokenize_chinese).to eq(true)
      end

      it "throws an error when the parameter is not a configurable site setting" do
        put "/admin/site_settings/clear_cache!.json",
            params: {
              clear_cache!: "",
              update_existing_user: true,
            }

        expect(response.status).to eq(422)
        expect(response.parsed_body["errors"]).to contain_exactly(
          "No setting named 'clear_cache!' exists",
        )
      end

      it "throws an error when trying to change a deprecated setting with override = false" do
        SiteSetting.personal_message_enabled_groups = Group::AUTO_GROUPS[:trust_level_4]
        put "/admin/site_settings/enable_personal_messages.json",
            params: {
              enable_personal_messages: false,
            }

        expect(response.status).to eq(422)
        expect(SiteSetting.personal_message_enabled_groups).to eq(
          Group::AUTO_GROUPS[:trust_level_4],
        )
      end

      it "allows value to be a blank string" do
        put "/admin/site_settings/test_setting.json", params: { test_setting: "" }
        expect(response.status).to eq(200)
        expect(SiteSetting.test_setting).to eq("")
      end

      context "with default user options" do
        let!(:user1) { Fabricate(:user) }
        let!(:user2) { Fabricate(:user) }

        it "should update all existing user options" do
          SiteSetting.default_email_in_reply_to = true

          user2.user_option.email_in_reply_to = true
          user2.user_option.save!

          put "/admin/site_settings/default_email_in_reply_to.json",
              params: {
                default_email_in_reply_to: false,
                update_existing_user: true,
              }

          user2.reload
          expect(user2.user_option.email_in_reply_to).to eq(false)
        end

        it "should not update existing user options" do
          expect {
            put "/admin/site_settings/default_email_in_reply_to.json",
                params: {
                  default_email_in_reply_to: false,
                }
          }.not_to change { UserOption.where(email_in_reply_to: false).count }
        end

        it "should update `email_digests` column in existing user options" do
          UserOption.last.update(email_digests: false)

          expect {
            put "/admin/site_settings/default_email_digest_frequency.json",
                params: {
                  default_email_digest_frequency: 30,
                  update_existing_user: true,
                }
          }.to change { UserOption.where(email_digests: true).count }.by(1)

          expect {
            put "/admin/site_settings/default_email_digest_frequency.json",
                params: {
                  default_email_digest_frequency: 0,
                  update_existing_user: true,
                }
          }.to change { UserOption.where(email_digests: false).count }.by(User.human_users.count)
        end
      end

      context "when updating default sidebar categories and tags" do
        it "does not enqueue the backfilling job if update_existing_user param is not present" do
          expect_not_enqueued_with(job: :backfill_sidebar_site_settings) do
            put "/admin/site_settings/default_sidebar_categories.json",
                params: {
                  default_sidebar_categories: "1|2",
                }

            expect(response.status).to eq(200)
          end
        end

        it "enqueus the backfilling job if update_existing_user param is present when updating default sidebar tags" do
          SiteSetting.default_sidebar_tags = "tag3"

          expect_enqueued_with(
            job: :backfill_sidebar_site_settings,
            args: {
              setting_name: "default_sidebar_tags",
              new_value: "tag1|tag2",
              previous_value: "tag3",
            },
          ) do
            put "/admin/site_settings/default_sidebar_tags.json",
                params: {
                  default_sidebar_tags: "tag1|tag2",
                  update_existing_user: true,
                }

            expect(response.status).to eq(200)
          end
        end

        it "enqueus the backfilling job if update_existing_user param is present when updating default sidebar categories" do
          SiteSetting.default_sidebar_categories = "3|4"

          expect_enqueued_with(
            job: :backfill_sidebar_site_settings,
            args: {
              setting_name: "default_sidebar_categories",
              new_value: "1|2",
              previous_value: "3|4",
            },
          ) do
            put "/admin/site_settings/default_sidebar_categories.json",
                params: {
                  default_sidebar_categories: "1|2",
                  update_existing_user: true,
                }

            expect(response.status).to eq(200)
          end
        end
      end

      context "with default categories" do
        fab!(:user1) { Fabricate(:user) }
        fab!(:user2) { Fabricate(:user) }
        fab!(:staged_user) { Fabricate(:staged) }
        let(:watching) { NotificationLevels.all[:watching] }
        let(:tracking) { NotificationLevels.all[:tracking] }

        let(:category_ids) { 3.times.collect { Fabricate(:category).id } }

        before do
          SiteSetting.setting(:default_categories_watching, category_ids.first(2).join("|"))
          CategoryUser.create!(
            category_id: category_ids.last,
            notification_level: tracking,
            user: user2,
          )
        end

        after { SiteSetting.setting(:default_categories_watching, "") }

        it "should update existing users user preference" do
          put "/admin/site_settings/default_categories_watching.json",
              params: {
                default_categories_watching: category_ids.last(2).join("|"),
                update_existing_user: true,
              }

          expect(response.status).to eq(200)
          expect(
            CategoryUser.where(category_id: category_ids.first, notification_level: watching).count,
          ).to eq(0)
          expect(
            CategoryUser.where(category_id: category_ids.last, notification_level: watching).count,
          ).to eq(User.real.where(staged: false).count - 1)

          topic = Fabricate(:topic, category_id: category_ids.last)
          topic_user1 =
            Fabricate(
              :topic_user,
              topic: topic,
              notification_level: TopicUser.notification_levels[:watching],
              notifications_reason_id: TopicUser.notification_reasons[:auto_watch_category],
            )
          topic_user2 =
            Fabricate(
              :topic_user,
              topic: topic,
              notification_level: TopicUser.notification_levels[:watching],
              notifications_reason_id: TopicUser.notification_reasons[:user_changed],
            )

          put "/admin/site_settings/default_categories_watching.json",
              params: {
                default_categories_watching: "",
                update_existing_user: true,
              }
          expect(response.status).to eq(200)
          expect(
            CategoryUser.where(category_id: category_ids, notification_level: watching).count,
          ).to eq(0)
          expect(topic_user1.reload.notification_level).to eq(
            TopicUser.notification_levels[:regular],
          )
          expect(topic_user2.reload.notification_level).to eq(
            TopicUser.notification_levels[:watching],
          )
        end

        it "should not update existing users user preference" do
          expect {
            put "/admin/site_settings/default_categories_watching.json",
                params: {
                  default_categories_watching: category_ids.last(2).join("|"),
                }
          }.not_to change {
            CategoryUser.where(category_id: category_ids.first, notification_level: watching).count
          }

          expect(response.status).to eq(200)
          expect(
            CategoryUser.where(category_id: category_ids.last, notification_level: watching).count,
          ).to eq(0)

          topic = Fabricate(:topic, category_id: category_ids.last)
          topic_user1 =
            Fabricate(
              :topic_user,
              topic: topic,
              notification_level: TopicUser.notification_levels[:watching],
              notifications_reason_id: TopicUser.notification_reasons[:auto_watch_category],
            )
          topic_user2 =
            Fabricate(
              :topic_user,
              topic: topic,
              notification_level: TopicUser.notification_levels[:watching],
              notifications_reason_id: TopicUser.notification_reasons[:user_changed],
            )
          put "/admin/site_settings/default_categories_watching.json",
              params: {
                default_categories_watching: "",
              }
          expect(response.status).to eq(200)
          expect(
            CategoryUser.where(category_id: category_ids.first, notification_level: watching).count,
          ).to eq(0)
          expect(topic_user1.reload.notification_level).to eq(
            TopicUser.notification_levels[:watching],
          )
          expect(topic_user2.reload.notification_level).to eq(
            TopicUser.notification_levels[:watching],
          )
        end
      end

      context "with default tags" do
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

        after { SiteSetting.setting(:default_tags_watching, "") }

        it "should update existing users user preference" do
          put "/admin/site_settings/default_tags_watching.json",
              params: {
                default_tags_watching: tags.last(2).pluck(:name).join("|"),
                update_existing_user: true,
              }

          expect(TagUser.where(tag_id: tags.first.id, notification_level: watching).count).to eq(0)
          expect(TagUser.where(tag_id: tags.last.id, notification_level: watching).count).to eq(
            User.real.where(staged: false).count - 1,
          )
        end

        it "should not update existing users user preference" do
          expect {
            put "/admin/site_settings/default_tags_watching.json",
                params: {
                  default_tags_watching: tags.last(2).pluck(:name).join("|"),
                }
          }.not_to change {
            TagUser.where(tag_id: tags.first.id, notification_level: watching).count
          }

          expect(TagUser.where(tag_id: tags.last.id, notification_level: watching).count).to eq(0)
        end
      end

      context "with upload site settings" do
        it "can remove the site setting" do
          SiteSetting.test_upload = Fabricate(:upload)

          put "/admin/site_settings/test_upload.json", params: { test_upload: nil }

          expect(response.status).to eq(200)
          expect(SiteSetting.test_upload).to eq(nil)
        end

        it "can reset the site setting to the default" do
          SiteSetting.test_upload = nil
          default_upload = Upload.find(-1)

          put "/admin/site_settings/test_upload.json", params: { test_upload: default_upload.url }

          expect(response.status).to eq(200)
          expect(SiteSetting.test_upload).to eq(default_upload)
        end

        it "can update the site setting" do
          upload = Fabricate(:upload)

          put "/admin/site_settings/test_upload.json", params: { test_upload: upload.url }

          expect(response.status).to eq(200)
          expect(SiteSetting.test_upload).to eq(upload)

          user_history = UserHistory.last

          expect(user_history.action).to eq(UserHistory.actions[:change_site_setting])

          expect(user_history.previous_value).to eq(nil)
          expect(user_history.new_value).to eq(upload.url)
        end
      end

      it "logs the change" do
        SiteSetting.test_setting = "previous"

        expect do
          put "/admin/site_settings/test_setting.json", params: { test_setting: "hello" }
        end.to change {
          UserHistory.where(action: UserHistory.actions[:change_site_setting]).count
        }.by(1)

        expect(response.status).to eq(200)
        expect(SiteSetting.test_setting).to eq("hello")
      end

      it "does not allow changing of hidden settings" do
        SiteSetting.setting(:hidden_setting, "hidden", hidden: true)
        SiteSetting.refresh!

        put "/admin/site_settings/hidden_setting.json", params: { hidden_setting: "not allowed" }

        expect(SiteSetting.hidden_setting).to eq("hidden")
        expect(response.status).to eq(422)
      end

      it "does not allow changing of hidden settings" do
        SiteSetting.setting(:hidden_setting, "hidden", hidden: true)
        SiteSetting.refresh!

        put "/admin/site_settings/hidden_setting.json", params: { hidden_setting: "not allowed" }

        expect(SiteSetting.hidden_setting).to eq("hidden")
        expect(response.status).to eq(422)
      end

      context "with an plugin" do
        let(:plugin) do
          metadata = Plugin::Metadata.new
          metadata.name = "discourse-plugin"
          Plugin::Instance.new(metadata)
        end

        before do
          Discourse.plugins_by_name[plugin.name] = plugin
          SiteSetting.setting(:plugin_setting, "default value", plugin: "discourse-plugin")
          SiteSetting.refresh!
        end

        after do
          Discourse.plugins_by_name.delete(plugin.name)
          SiteSetting.remove_setting(:plugin_setting)
        end

        it "allows changing settings of configurable plugins" do
          plugin.stubs(:configurable?).returns(true)

          put "/admin/site_settings/plugin_setting.json", params: { plugin_setting: "new value" }

          expect(SiteSetting.plugin_setting).to eq("new value")
          expect(response.status).to eq(200)
        end

        it "does not allow changing of unconfigurable settings" do
          plugin.stubs(:configurable?).returns(false)

          put "/admin/site_settings/plugin_setting.json", params: { plugin_setting: "not allowed" }

          expect(SiteSetting.plugin_setting).to eq("default value")
          expect(response.status).to eq(422)
        end
      end

      it "fails when a setting does not exist" do
        put "/admin/site_settings/provider.json", params: { provider: "gotcha" }
        expect(response.status).to eq(422)
      end
    end

    shared_examples "site setting update not allowed" do
      it "prevents updates with a 404 response" do
        put "/admin/site_settings/test_setting.json", params: { test_setting: "hello" }

        expect(response.status).to eq(404)
        expect(response.parsed_body["errors"]).to include(I18n.t("not_found"))
      end
    end

    context "when logged in as a moderator" do
      before { sign_in(moderator) }

      include_examples "site setting update not allowed"
    end

    context "when logged in as a non-staff user" do
      before { sign_in(user) }

      include_examples "site setting update not allowed"
    end
  end
end
