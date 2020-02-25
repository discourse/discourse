# frozen_string_literal: true

require 'rails_helper'

describe UserSerializer do

  context "with a TL0 user seen as anonymous" do
    let(:user) { Fabricate.build(:user, trust_level: 0, user_profile: Fabricate.build(:user_profile)) }
    let(:serializer) { UserSerializer.new(user, scope: Guardian.new, root: false) }
    let(:json) { serializer.as_json }

    let(:untrusted_attributes) { %i{bio_raw bio_cooked bio_excerpt location website website_name profile_background card_background} }

    it "doesn't serialize untrusted attributes" do
      untrusted_attributes.each { |attr| expect(json).not_to have_key(attr) }
    end
  end

  context "as current user" do
    it "serializes options correctly" do
      # so we serialize more stuff
      SiteSetting.default_other_auto_track_topics_after_msecs = 0
      SiteSetting.default_other_notification_level_when_replying = 3
      SiteSetting.default_other_new_topic_duration_minutes = 60 * 24

      user = Fabricate.build(:user,
                              user_profile: Fabricate.build(:user_profile),
                              user_option: UserOption.new(dynamic_favicon: true),
                              user_stat: UserStat.new
                            )

      json = UserSerializer.new(user, scope: Guardian.new(user), root: false).as_json

      expect(json[:user_option][:dynamic_favicon]).to eq(true)
      expect(json[:user_option][:new_topic_duration_minutes]).to eq(60 * 24)
      expect(json[:user_option][:auto_track_topics_after_msecs]).to eq(0)
      expect(json[:user_option][:notification_level_when_replying]).to eq(3)

    end
  end

  context "with a user" do
    let(:scope) { Guardian.new }
    fab!(:user) { Fabricate(:user) }
    let(:serializer) { UserSerializer.new(user, scope: scope, root: false) }
    let(:json) { serializer.as_json }
    fab!(:upload) { Fabricate(:upload) }
    fab!(:upload2) { Fabricate(:upload) }

    context "with `enable_names` true" do
      before do
        SiteSetting.enable_names = true
      end

      it "has a name" do
        expect(json[:name]).to be_present
      end
    end

    context "with `enable_names` false" do
      before do
        SiteSetting.enable_names = false
      end

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
        before do
          user.user_profile.website = 'http://example.com/user'
        end

        it "has a website with a path" do
          expect(json[:website]).to eq 'http://example.com/user'
        end

        it "returns complete website name with path" do
          expect(json[:website_name]).to eq 'example.com/user'
        end
      end

      context "when website has a subdomain" do
        before do
          user.user_profile.website = 'http://subdomain.example.com/user'
        end

        it "has a website with a subdomain" do
          expect(json[:website]).to eq 'http://subdomain.example.com/user'
        end

        it "returns website name with the subdomain" do
          expect(json[:website_name]).to eq 'subdomain.example.com/user'
        end
      end

      context "when website has www" do
        before do
          user.user_profile.website = 'http://www.example.com/user'
        end

        it "has a website with the www" do
          expect(json[:website]).to eq 'http://www.example.com/user'
        end

        it "returns website name without the www" do
          expect(json[:website_name]).to eq 'example.com/user'
        end
      end

      context "when website includes query parameters" do
        before do
          user.user_profile.website = 'http://example.com/user?ref=payme'
        end

        it "has a website with query params" do
          expect(json[:website]).to eq 'http://example.com/user?ref=payme'
        end

        it "has a website name without query params" do
          expect(json[:website_name]).to eq 'example.com/user'
        end
      end

      context "when website is not a valid url" do
        before do
          user.user_profile.website = 'invalid-url'
        end

        it "has a website with the invalid url" do
          expect(json[:website]).to eq 'invalid-url'
        end

        it "has a nil website name" do
          expect(json[:website_name]).to eq nil
        end
      end
    end

    context "with filled out bio" do
      before do
        user.user_profile.bio_raw = 'my raw bio'
        user.user_profile.bio_cooked = 'my cooked bio'
      end

      it "has a bio" do
        expect(json[:bio_raw]).to eq 'my raw bio'
      end

      it "has a cooked bio" do
        expect(json[:bio_cooked]).to eq 'my cooked bio'
      end
    end

    describe "second_factor_enabled" do
      let(:scope) { Guardian.new(user) }
      it "is false by default" do
        expect(json[:second_factor_enabled]).to eq(false)
      end

      context "when totp enabled" do
        before do
          User.any_instance.stubs(:totp_enabled?).returns(true)
        end

        it "is true" do
          expect(json[:second_factor_enabled]).to eq(true)
        end
      end

      context "when security_keys enabled" do
        before do
          User.any_instance.stubs(:security_keys_enabled?).returns(true)
        end

        it "is true" do
          expect(json[:second_factor_enabled]).to eq(true)
        end
      end
    end

    describe "ignored and muted" do
      fab!(:viewing_user) { Fabricate(:user) }
      let(:scope) { Guardian.new(viewing_user) }

      it 'returns false values for muted and ignored' do
        expect(json[:ignored]).to eq(false)
        expect(json[:muted]).to eq(false)
      end

      context 'when ignored' do
        before do
          Fabricate(:ignored_user, user: viewing_user, ignored_user: user)
          viewing_user.reload
        end

        it 'returns true for ignored' do
          expect(json[:ignored]).to eq(true)
          expect(json[:muted]).to eq(false)
        end
      end

      context 'when muted' do
        before do
          Fabricate(:muted_user, user: viewing_user, muted_user: user)
          viewing_user.reload
        end

        it 'returns true for muted' do
          expect(json[:muted]).to eq(true)
          expect(json[:ignored]).to eq(false)
        end
      end

    end
  end

  context "with custom_fields" do
    fab!(:user) { Fabricate(:user) }
    let(:json) { UserSerializer.new(user, scope: Guardian.new, root: false).as_json }

    before do
      user.custom_fields['secret_field'] = 'Only for me to know'
      user.custom_fields['public_field'] = 'Everyone look here'
      user.save
    end

    it "doesn't serialize the fields by default" do
      json[:custom_fields]
      expect(json[:custom_fields]).to be_empty
    end

    it "serializes the fields listed in public_user_custom_fields site setting" do
      SiteSetting.public_user_custom_fields = 'public_field'
      expect(json[:custom_fields]['public_field']).to eq(user.custom_fields['public_field'])
      expect(json[:custom_fields]['secret_field']).to eq(nil)
    end

    context "with user custom field" do
      before do
        plugin = Plugin::Instance.new
        plugin.whitelist_public_user_custom_field :public_field
      end

      after do
        User.plugin_public_user_custom_fields.clear
      end

      it "serializes the fields listed in plugin_public_user_custom_fields" do
        expect(json[:custom_fields]['public_field']).to eq(user.custom_fields['public_field'])
        expect(json[:custom_fields]['secret_field']).to eq(nil)
      end
    end
  end

  context "with user fields" do
    fab!(:user) { Fabricate(:user) }

    let! :fields do
      [
        Fabricate(:user_field),
        Fabricate(:user_field),
        Fabricate(:user_field, show_on_profile: true),
        Fabricate(:user_field, show_on_user_card: true),
        Fabricate(:user_field, show_on_user_card: true, show_on_profile: true)
      ]
    end

    let(:other_user_json) { UserSerializer.new(user, scope: Guardian.new(Fabricate(:user)), root: false).as_json }
    let(:self_json) { UserSerializer.new(user, scope: Guardian.new(user), root: false).as_json }
    let(:admin_json) { UserSerializer.new(user, scope: Guardian.new(Fabricate(:admin)), root: false).as_json }

    it "includes the correct fields for each audience" do
      expect(admin_json[:user_fields].keys).to contain_exactly(*fields.map { |f| f.id.to_s })
      expect(other_user_json[:user_fields].keys).to contain_exactly(*fields[2..5].map { |f| f.id.to_s })
      expect(self_json[:user_fields].keys).to contain_exactly(*fields.map { |f| f.id.to_s })
    end

  end

  context "with user_api_keys" do
    fab!(:user) { Fabricate(:user) }

    it "sorts keys by last used time" do
      freeze_time

      user_api_key_0 = Fabricate(:readonly_user_api_key, user: user, last_used_at: 2.days.ago, revoked_at: Time.zone.now)
      user_api_key_1 = Fabricate(:readonly_user_api_key, user: user, last_used_at: 7.days.ago)
      user_api_key_2 = Fabricate(:readonly_user_api_key, user: user, last_used_at: 1.days.ago)
      user_api_key_3 = Fabricate(:readonly_user_api_key, user: user, last_used_at: 4.days.ago, revoked_at: Time.zone.now)
      user_api_key_4 = Fabricate(:readonly_user_api_key, user: user, last_used_at: 3.days.ago)

      json = UserSerializer.new(user, scope: Guardian.new(user), root: false).as_json

      expect(json[:user_api_keys].size).to eq(3)
      expect(json[:user_api_keys][0][:id]).to eq(user_api_key_1.id)
      expect(json[:user_api_keys][1][:id]).to eq(user_api_key_4.id)
      expect(json[:user_api_keys][2][:id]).to eq(user_api_key_2.id)
    end
  end
end
