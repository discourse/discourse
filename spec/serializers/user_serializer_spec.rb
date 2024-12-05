# frozen_string_literal: true

RSpec.describe UserSerializer do
  fab!(:user) { Fabricate(:user, trust_level: 0) }

  before { user.user_stat.update!(post_count: 1) }

  context "with a TL0 user seen as anonymous" do
    let(:serializer) { UserSerializer.new(user, scope: Guardian.new, root: false) }
    let(:json) { serializer.as_json }
    let(:untrusted_attributes) do
      %i[
        bio_raw
        bio_cooked
        bio_excerpt
        location
        website
        website_name
        profile_background
        card_background
      ]
    end

    it "doesn't serialize untrusted attributes" do
      untrusted_attributes.each { |attr| expect(json).not_to have_key(attr) }
    end

    it "serializes correctly" do
      expect(json[:group_users]).to eq(nil)
      expect(json[:second_factor_enabled]).to eq(nil)
    end
  end

  context "as moderator" do
    it "serializes correctly" do
      json =
        UserSerializer.new(user, scope: Guardian.new(Fabricate(:moderator)), root: false).as_json

      expect(json[:group_users]).to eq(nil)
      expect(json[:second_factor_enabled]).to eq(nil)
    end
  end

  context "as current user" do
    it "serializes options correctly" do
      # so we serialize more stuff
      SiteSetting.default_other_auto_track_topics_after_msecs = 0
      SiteSetting.default_other_notification_level_when_replying = 3
      SiteSetting.default_other_new_topic_duration_minutes = 60 * 24

      user = Fabricate(:user)
      user.user_option.update(dynamic_favicon: true, skip_new_user_tips: true)

      json = UserSerializer.new(user, scope: Guardian.new(user), root: false).as_json

      expect(json[:user_option][:dynamic_favicon]).to eq(true)
      expect(json[:user_option][:skip_new_user_tips]).to eq(true)
      expect(json[:user_option][:new_topic_duration_minutes]).to eq(60 * 24)
      expect(json[:user_option][:auto_track_topics_after_msecs]).to eq(0)
      expect(json[:user_option][:notification_level_when_replying]).to eq(3)
      expect(json[:group_users]).to eq([])
      expect(json[:second_factor_enabled]).to eq(false)
    end
  end

  context "with a user" do
    let(:admin_user) { Fabricate(:admin) }
    let(:scope) { Guardian.new }
    fab!(:user)
    let(:serializer) { UserSerializer.new(user, scope: scope, root: false) }
    let(:json) { serializer.as_json }
    fab!(:upload)
    fab!(:upload2) { Fabricate(:upload) }

    context "when the scope user is admin" do
      let(:scope) { Guardian.new(admin_user) }

      it "returns the user's category notification levels, not the scope user's" do
        category1 = Fabricate(:category)
        category2 = Fabricate(:category)
        category3 = Fabricate(:category)
        category4 = Fabricate(:category)
        CategoryUser.create(
          category: category1,
          user: user,
          notification_level: CategoryUser.notification_levels[:muted],
        )
        CategoryUser.create(
          category: Fabricate(:category),
          user: admin_user,
          notification_level: CategoryUser.notification_levels[:muted],
        )
        CategoryUser.create(
          category: category2,
          user: user,
          notification_level: CategoryUser.notification_levels[:tracking],
        )
        CategoryUser.create(
          category: Fabricate(:category),
          user: admin_user,
          notification_level: CategoryUser.notification_levels[:tracking],
        )
        CategoryUser.create(
          category: category3,
          user: user,
          notification_level: CategoryUser.notification_levels[:watching],
        )
        CategoryUser.create(
          category: Fabricate(:category),
          user: admin_user,
          notification_level: CategoryUser.notification_levels[:watching],
        )
        CategoryUser.create(
          category: category4,
          user: user,
          notification_level: CategoryUser.notification_levels[:regular],
        )
        CategoryUser.create(
          category: Fabricate(:category),
          user: admin_user,
          notification_level: CategoryUser.notification_levels[:regular],
        )

        expect(json[:muted_category_ids]).to eq([category1.id])
        expect(json[:tracked_category_ids]).to eq([category2.id])
        expect(json[:watched_category_ids]).to eq([category3.id])
        expect(json[:regular_category_ids]).to eq([category4.id])
      end

      it "returns the user's tag notification levels, not the scope user's" do
        tag1 = Fabricate(:tag)
        tag2 = Fabricate(:tag)
        tag3 = Fabricate(:tag)
        tag4 = Fabricate(:tag)
        TagUser.create(
          tag: tag1,
          user: user,
          notification_level: TagUser.notification_levels[:muted],
        )
        TagUser.create(
          tag: Fabricate(:tag),
          user: admin_user,
          notification_level: TagUser.notification_levels[:muted],
        )
        TagUser.create(
          tag: tag2,
          user: user,
          notification_level: TagUser.notification_levels[:tracking],
        )
        TagUser.create(
          tag: Fabricate(:tag),
          user: admin_user,
          notification_level: TagUser.notification_levels[:tracking],
        )
        TagUser.create(
          tag: tag3,
          user: user,
          notification_level: TagUser.notification_levels[:watching],
        )
        TagUser.create(
          tag: Fabricate(:tag),
          user: admin_user,
          notification_level: TagUser.notification_levels[:watching],
        )
        TagUser.create(
          tag: tag4,
          user: user,
          notification_level: TagUser.notification_levels[:watching_first_post],
        )
        TagUser.create(
          tag: Fabricate(:tag),
          user: admin_user,
          notification_level: TagUser.notification_levels[:watching_first_post],
        )

        expect(json[:muted_tags]).to eq([tag1.name])
        expect(json[:tracked_tags]).to eq([tag2.name])
        expect(json[:watched_tags]).to eq([tag3.name])
        expect(json[:watching_first_post_tags]).to eq([tag4.name])
      end
    end

    context "with `enable_names` true" do
      before { SiteSetting.enable_names = true }

      it "has a name" do
        expect(json[:name]).to be_present
      end
    end

    context "with `enable_names` false" do
      before { SiteSetting.enable_names = false }

      it "has a name" do
        expect(json[:name]).to be_blank
      end
    end

    context "with filled out backgrounds" do
      before do
        user.user_profile.upload_card_background(upload)
        user.user_profile.upload_profile_background(upload2)
      end

      it "has a profile background" do
        expect(json[:card_background_upload_url]).to eq(upload.url)
        expect(json[:profile_background_upload_url]).to eq(upload2.url)
      end
    end

    context "with filled out website" do
      context "when website has a path" do
        before { user.user_profile.website = "http://example.com/user" }

        it "has a website with a path" do
          expect(json[:website]).to eq "http://example.com/user"
        end

        it "returns complete website name with path" do
          expect(json[:website_name]).to eq "example.com/user"
        end
      end

      context "when website has a subdomain" do
        before { user.user_profile.website = "http://subdomain.example.com/user" }

        it "has a website with a subdomain" do
          expect(json[:website]).to eq "http://subdomain.example.com/user"
        end

        it "returns website name with the subdomain" do
          expect(json[:website_name]).to eq "subdomain.example.com/user"
        end
      end

      context "when website has www" do
        before { user.user_profile.website = "http://www.example.com/user" }

        it "has a website with the www" do
          expect(json[:website]).to eq "http://www.example.com/user"
        end

        it "returns website name without the www" do
          expect(json[:website_name]).to eq "example.com/user"
        end
      end

      context "when website includes query parameters" do
        before { user.user_profile.website = "http://example.com/user?ref=payme" }

        it "has a website with query params" do
          expect(json[:website]).to eq "http://example.com/user?ref=payme"
        end

        it "has a website name without query params" do
          expect(json[:website_name]).to eq "example.com/user"
        end
      end

      context "when website is not a valid url" do
        before { user.user_profile.website = "invalid-url" }

        it "has a website with the invalid url" do
          expect(json[:website]).to eq "invalid-url"
        end

        it "has a nil website name" do
          expect(json[:website_name]).to eq nil
        end
      end
    end

    context "with filled out bio" do
      before do
        user.user_profile.bio_raw = "my raw bio"
        user.user_profile.bio_cooked = "my cooked bio"
      end

      it "has a bio" do
        expect(json[:bio_raw]).to eq "my raw bio"
      end

      it "has a cooked bio" do
        expect(json[:bio_cooked]).to eq "my cooked bio"
      end
    end

    describe "second_factor_enabled" do
      let(:scope) { Guardian.new(user) }
      it "is false by default" do
        expect(json[:second_factor_enabled]).to eq(false)
      end

      context "when totp enabled" do
        before { User.any_instance.stubs(:totp_enabled?).returns(true) }

        it "is true" do
          expect(json[:second_factor_enabled]).to eq(true)
        end
      end

      context "when security_keys enabled" do
        before { User.any_instance.stubs(:security_keys_enabled?).returns(true) }

        it "is true" do
          expect(json[:second_factor_enabled]).to eq(true)
        end
      end
    end

    describe "ignored and muted" do
      fab!(:viewing_user) { Fabricate(:user) }
      let(:scope) { Guardian.new(viewing_user) }

      it "returns false values for muted and ignored" do
        expect(json[:ignored]).to eq(false)
        expect(json[:muted]).to eq(false)
      end

      context "when ignored" do
        before do
          Fabricate(:ignored_user, user: viewing_user, ignored_user: user)
          viewing_user.reload
        end

        it "returns true for ignored" do
          expect(json[:ignored]).to eq(true)
          expect(json[:muted]).to eq(false)
        end
      end

      context "when muted" do
        before do
          Fabricate(:muted_user, user: viewing_user, muted_user: user)
          viewing_user.reload
        end

        it "returns true for muted" do
          expect(json[:muted]).to eq(true)
          expect(json[:ignored]).to eq(false)
        end
      end
    end

    describe "with a custom notification schedule" do
      let(:schedule) do
        UserNotificationSchedule.create({ user: user }.merge(UserNotificationSchedule::DEFAULT))
      end
      let(:scope) { Guardian.new(user) }

      it "includes the serialized schedule" do
        expect(json[:user_notification_schedule][:enabled]).to eq(schedule[:enabled])
        expect(json[:user_notification_schedule][:day_0_start_time]).to eq(
          schedule[:day_0_start_time],
        )
        expect(json[:user_notification_schedule][:day_6_end_time]).to eq(schedule[:day_6_end_time])
      end
    end
  end

  context "with custom_fields" do
    fab!(:user)
    let(:json) { UserSerializer.new(user, scope: Guardian.new, root: false).as_json }

    before do
      user.custom_fields["secret_field"] = "Only for me to know"
      user.custom_fields["public_field"] = "Everyone look here"
      user.save
    end

    it "doesn't serialize the fields by default" do
      json[:custom_fields]
      expect(json[:custom_fields]).to be_empty
    end

    it "serializes the fields listed in public_user_custom_fields site setting" do
      SiteSetting.public_user_custom_fields = "public_field"
      expect(json[:custom_fields]["public_field"]).to eq(user.custom_fields["public_field"])
      expect(json[:custom_fields]["secret_field"]).to eq(nil)
    end

    context "with user custom field" do
      before do
        plugin = Plugin::Instance.new
        plugin.allow_public_user_custom_field :public_field
      end

      after { DiscoursePluginRegistry.reset! }

      it "serializes the fields listed in public_user_custom_fields" do
        expect(json[:custom_fields]["public_field"]).to eq(user.custom_fields["public_field"])
        expect(json[:custom_fields]["secret_field"]).to eq(nil)
      end
    end
  end

  context "with user fields" do
    fab!(:user)

    let! :fields do
      [
        Fabricate(:user_field),
        Fabricate(:user_field),
        Fabricate(:user_field, show_on_profile: true),
        Fabricate(:user_field, show_on_user_card: true),
        Fabricate(:user_field, show_on_user_card: true, show_on_profile: true),
      ]
    end

    let(:other_user_json) do
      UserSerializer.new(user, scope: Guardian.new(Fabricate(:user)), root: false).as_json
    end
    let(:self_json) { UserSerializer.new(user, scope: Guardian.new(user), root: false).as_json }
    let(:admin_json) do
      UserSerializer.new(user, scope: Guardian.new(Fabricate(:admin)), root: false).as_json
    end

    it "includes the correct fields for each audience" do
      expect(admin_json[:user_fields].keys).to contain_exactly(*fields.map { |f| f.id.to_s })
      expect(other_user_json[:user_fields].keys).to contain_exactly(
        *fields[2..5].map { |f| f.id.to_s },
      )
      expect(self_json[:user_fields].keys).to contain_exactly(*fields.map { |f| f.id.to_s })
    end
  end

  context "with user_api_keys" do
    fab!(:user)

    it "sorts keys by last used time" do
      freeze_time

      user_api_key_0 =
        Fabricate(
          :readonly_user_api_key,
          user: user,
          last_used_at: 2.days.ago,
          revoked_at: Time.zone.now,
        )
      user_api_key_1 = Fabricate(:readonly_user_api_key, user: user, last_used_at: 7.days.ago)
      user_api_key_2 = Fabricate(:readonly_user_api_key, user: user, last_used_at: 1.days.ago)
      user_api_key_3 =
        Fabricate(
          :readonly_user_api_key,
          user: user,
          last_used_at: 4.days.ago,
          revoked_at: Time.zone.now,
        )
      user_api_key_4 = Fabricate(:readonly_user_api_key, user: user, last_used_at: 3.days.ago)

      json = UserSerializer.new(user, scope: Guardian.new(user), root: false).as_json

      expect(json[:user_api_keys].size).to eq(3)
      expect(json[:user_api_keys][0][:id]).to eq(user_api_key_1.id)
      expect(json[:user_api_keys][1][:id]).to eq(user_api_key_4.id)
      expect(json[:user_api_keys][2][:id]).to eq(user_api_key_2.id)
    end
  end

  context "with user_passkeys" do
    fab!(:user)
    fab!(:passkey0) do
      Fabricate(:passkey_with_random_credential, user: user, created_at: 5.hours.ago)
    end
    fab!(:passkey1) do
      Fabricate(:passkey_with_random_credential, user: user, created_at: 2.hours.ago)
    end

    it "does not include them if feature is disabled" do
      SiteSetting.enable_passkeys = false
      json = UserSerializer.new(user, scope: Guardian.new(user), root: false).as_json

      expect(json[:user_passkeys]).to eq(nil)
    end

    it "does not include them if requesting user isn't current user" do
      SiteSetting.enable_passkeys = true
      json = UserSerializer.new(user, scope: Guardian.new(), root: false).as_json

      expect(json[:user_passkeys]).to eq(nil)
    end

    it "includes passkeys if feature is enabled for current user" do
      SiteSetting.enable_passkeys = true

      json = UserSerializer.new(user, scope: Guardian.new(user), root: false).as_json

      expect(json[:user_passkeys][0][:id]).to eq(passkey0.id)
      expect(json[:user_passkeys][0][:name]).to eq(passkey0.name)
      expect(json[:user_passkeys][0][:last_used]).to eq(passkey0.last_used)
      expect(json[:user_passkeys][1][:id]).to eq(passkey1.id)
    end
  end

  context "for user sidebar attributes" do
    include_examples "User Sidebar Serializer Attributes", described_class

    it "does not include attributes when scoped to user that cannot edit user" do
      user2 = Fabricate(:user)
      serializer = described_class.new(user, scope: Guardian.new(user2), root: false)

      expect(serializer.as_json[:sidebar_category_ids]).to eq(nil)
      expect(serializer.as_json[:sidebar_tags]).to eq(nil)
      expect(serializer.as_json[:display_sidebar_tags]).to eq(nil)
    end
  end

  context "with groups" do
    fab!(:group) do
      Fabricate(
        :group,
        visibility_level: Group.visibility_levels[:public],
        members_visibility_level: Group.visibility_levels[:owners],
      )
    end
    let(:serializer) { UserSerializer.new(user, scope: guardian, root: false) }

    before do
      group.add(user)
      group.save!
    end

    context "when serializing user's own groups" do
      let(:guardian) { Guardian.new(user) }

      it "includes secret membership group" do
        json = serializer.as_json
        expect(json[:groups].map { |g| g[:id] }).to include(group.id)
      end
    end

    context "when serializing other users' groups" do
      let(:guardian) { Guardian.new }

      it "does not include secret membership group" do
        json = serializer.as_json
        expect(json[:groups]).to be_empty
      end
    end
  end
end
