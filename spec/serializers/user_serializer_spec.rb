require 'rails_helper'
require_dependency 'user'

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
    let(:user) { Fabricate.build(:user, user_profile: Fabricate.build(:user_profile)) }
    let(:serializer) { UserSerializer.new(user, scope: Guardian.new, root: false) }
    let(:json) { serializer.as_json }

    it "produces json" do
      expect(json).to be_present
    end

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

    context "with filled out card background" do
      before do
        user.user_profile.card_background = 'http://card.com'
      end

      it "has a profile background" do
        expect(json[:card_background]).to eq 'http://card.com'
      end
    end

    context "with filled out profile background" do
      before do
        user.user_profile.profile_background = 'http://background.com'
      end

      it "has a profile background" do
        expect(json[:profile_background]).to eq 'http://background.com'
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
  end

  context "with custom_fields" do
    let(:user) { Fabricate(:user) }
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
  end

  context "with secondary emails" do
    let(:user) { Fabricate(:user_single_email) }

    before do
      ["first", "second"].each do |name|
        Fabricate(:secondary_email, user: user, email: "#{name}@email.com")
      end
    end

    shared_examples "shown" do
      it "contains the user's secondary emails" do
        expect(json[:secondary_emails]).to contain_exactly(
          "first@email.com",
          "second@email.com"
        )
      end
    end

    shared_examples "not shown" do
      it "doesn't contain the user's secondary emails" do
        secondary_emails = json[:secondary_emails]
        expect(secondary_emails).to be_nil
      end
    end

    shared_examples "staged shown" do
      context "with a staged user" do
        before do
          user.staged = true
        end

        include_examples "shown"
      end
    end

    context "as the user" do
      let(:json) { UserSerializer.new(user, scope: Guardian.new(user), root: false).as_json }
      include_examples "shown"
    end

    context "as an admin" do
      let(:admin) { Fabricate(:admin) }
      let(:json) { UserSerializer.new(user, scope: Guardian.new(admin), root: false).as_json }
      include_examples "not shown"
      include_examples "staged shown"
    end

    context "as a moderator" do
      let(:moderator) { Fabricate(:moderator) }
      let(:json) { UserSerializer.new(user, scope: Guardian.new(moderator), root: false).as_json }
      include_examples "not shown"
      include_examples "staged shown"
    end

    context "as another user" do
      let(:user2) { Fabricate(:user) }
      let(:json) { UserSerializer.new(user, scope: Guardian.new(user2), root: false).as_json }
      include_examples "not shown"
    end

    context "as an anonymous user" do
      let(:json) { UserSerializer.new(user, scope: Guardian.new, root: false).as_json }
      include_examples "not shown"
    end
  end
end
