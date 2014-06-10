require 'spec_helper'

describe UserProfile do
  it 'is created automatically when a user is created' do
    user = Fabricate(:evil_trout)
    user.user_profile.should be_present
  end

  describe 'new' do
    let(:user_profile) { Fabricate.build(:user_profile) }

    it 'is not valid without user' do
      expect(user_profile.valid?).to be_false
    end

    it 'is is valid with user' do
      user_profile.user = Fabricate.build(:user)
      expect(user_profile.valid?).to be_true
    end

    describe 'after save' do
      let(:user) { Fabricate(:user) }

      before do
        user.user_profile.bio_raw = 'my bio'
        user.user_profile.save
      end

      it 'has cooked bio' do
        expect(user.user_profile.bio_cooked).to be_present
      end

      it 'has bio summary' do
        expect(user.user_profile.bio_summary).to be_present
      end
    end
  end

  describe 'changing bio' do
    let(:user) { Fabricate(:user) }

    before do
      user.user_profile.bio_raw = "**turtle power!**"
      user.user_profile.save
      user.user_profile.reload
    end

    it 'should markdown the raw_bio and put it in cooked_bio' do
      user.user_profile.bio_cooked.should == "<p><strong>turtle power!</strong></p>"
    end
  end

  describe 'bio link stripping' do

    it 'returns an empty string with no bio' do
      expect(Fabricate.build(:user_profile).bio_excerpt).to be_blank
    end

    context 'with a user that has a link in their bio' do
      let(:user_profile) { Fabricate.build(:user_profile, bio_raw: "im sissy and i love http://ponycorns.com") }
      let(:user) do
        user = Fabricate.build(:user, user_profile: user_profile)
        user_profile.user = user
        user
      end

      let(:created_user) do
        user = Fabricate(:user)
        user.user_profile.bio_raw = 'im sissy and i love http://ponycorns.com'
        user.user_profile.save!
        user
      end

      it 'includes the link as nofollow if the user is not new' do
        user.user_profile.send(:cook)
        expect(user_profile.bio_excerpt).to eq("im sissy and i love <a href='http://ponycorns.com' rel='nofollow'>http://ponycorns.com</a>")
        expect(user_profile.bio_processed).to eq("<p>im sissy and i love <a href=\"http://ponycorns.com\" rel=\"nofollow\">http://ponycorns.com</a></p>")
      end

      it 'removes the link if the user is new' do
        user.trust_level = TrustLevel.levels[:newuser]
        user_profile.send(:cook)
        expect(user_profile.bio_excerpt).to eq("im sissy and i love http://ponycorns.com")
        expect(user_profile.bio_processed).to eq("<p>im sissy and i love http://ponycorns.com</p>")
      end

      it 'includes the link without nofollow if the user is trust level 3 or higher' do
        user.trust_level = TrustLevel.levels[:leader]
        user_profile.send(:cook)
        expect(user_profile.bio_excerpt).to eq("im sissy and i love <a href='http://ponycorns.com'>http://ponycorns.com</a>")
        expect(user_profile.bio_processed).to eq("<p>im sissy and i love <a href=\"http://ponycorns.com\">http://ponycorns.com</a></p>")
      end

      it 'removes nofollow from links in bio when trust level is increased' do
        created_user.change_trust_level!(:leader)
        expect(created_user.user_profile.bio_excerpt).to eq("im sissy and i love <a href='http://ponycorns.com'>http://ponycorns.com</a>")
        expect(created_user.user_profile.bio_processed).to eq("<p>im sissy and i love <a href=\"http://ponycorns.com\">http://ponycorns.com</a></p>")
      end

      it 'adds nofollow to links in bio when trust level is decreased' do
        created_user.trust_level = TrustLevel.levels[:leader]
        created_user.save
        created_user.change_trust_level!(:regular)
        expect(created_user.user_profile.bio_excerpt).to eq("im sissy and i love <a href='http://ponycorns.com' rel='nofollow'>http://ponycorns.com</a>")
        expect(created_user.user_profile.bio_processed).to eq("<p>im sissy and i love <a href=\"http://ponycorns.com\" rel=\"nofollow\">http://ponycorns.com</a></p>")
      end
    end
  end
end
