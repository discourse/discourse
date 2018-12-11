require 'rails_helper'

describe Auth::ManagedAuthenticator do
  let(:authenticator) {
    Class.new(described_class) do
      def name
        "myauth"
      end
    end.new
  }

  let(:hash) {
    {
      provider: "myauth",
      uid: "1234",
      info: {
        name: "Best Display Name",
        email: "awesome@example.com",
        nickname: "IAmGroot"
      },
      credentials: {
        token: "supersecrettoken"
      },
      extra: {
        raw_info: {
          randominfo: "some info"
        }
      }
    }
  }

  let(:create_hash) {
    {
      provider: "myauth",
      uid: "1234"
    }
  }

  describe 'after_authenticate' do
    it 'can match account from an existing association' do
      user = Fabricate(:user)
      associated = UserAssociatedAccount.create!(user: user, provider_name: 'myauth', provider_uid: "1234")
      result = authenticator.after_authenticate(hash)

      expect(result.user.id).to eq(user.id)
      associated.reload
      expect(associated.info["name"]).to eq("Best Display Name")
      expect(associated.info["email"]).to eq("awesome@example.com")
      expect(associated.credentials["token"]).to eq("supersecrettoken")
      expect(associated.extra["raw_info"]["randominfo"]).to eq("some info")
    end

    describe 'connecting to another user account' do
      let(:user1) { Fabricate(:user) }
      let(:user2) { Fabricate(:user) }
      before { UserAssociatedAccount.create!(user: user1, provider_name: 'myauth', provider_uid: "1234") }

      it 'works by default' do
        result = authenticator.after_authenticate(hash, existing_account: user2)
        expect(result.user.id).to eq(user2.id)
        expect(UserAssociatedAccount.exists?(user_id: user1.id)).to eq(false)
        expect(UserAssociatedAccount.exists?(user_id: user2.id)).to eq(true)
      end

      it 'still works if another user has a matching email' do
        Fabricate(:user, email: hash.dig(:info, :email))
        result = authenticator.after_authenticate(hash, existing_account: user2)
        expect(result.user.id).to eq(user2.id)
        expect(UserAssociatedAccount.exists?(user_id: user1.id)).to eq(false)
        expect(UserAssociatedAccount.exists?(user_id: user2.id)).to eq(true)
      end

      it 'does not work when disabled' do
        authenticator = Class.new(described_class) do
          def name
            "myauth"
          end
          def can_connect_existing_user?
            false
          end
        end.new
        result = authenticator.after_authenticate(hash, existing_account: user2)
        expect(result.user.id).to eq(user1.id)
        expect(UserAssociatedAccount.exists?(user_id: user1.id)).to eq(true)
        expect(UserAssociatedAccount.exists?(user_id: user2.id)).to eq(false)
      end
    end

    describe 'match by email' do
      it 'works normally' do
        user = Fabricate(:user)
        result = authenticator.after_authenticate(hash.deep_merge(info: { email: user.email }))
        expect(result.user.id).to eq(user.id)
        expect(UserAssociatedAccount.find_by(provider_name: 'myauth', provider_uid: "1234").user_id).to eq(user.id)
      end

      it 'works if there is already an association with the target account' do
        user = Fabricate(:user, email: "awesome@example.com")
        result = authenticator.after_authenticate(hash)
        expect(result.user.id).to eq(user.id)
      end

      it 'does not match if match_by_email is false' do
        authenticator = Class.new(described_class) do
          def name
            "myauth"
          end
          def match_by_email
            false
          end
        end.new
        user = Fabricate(:user, email: "awesome@example.com")
        result = authenticator.after_authenticate(hash)
        expect(result.user).to eq(nil)
      end
    end

    context 'when no matching user' do
      it 'returns the correct information' do
        expect {
          result = authenticator.after_authenticate(hash)
          expect(result.user).to eq(nil)
          expect(result.username).to eq("IAmGroot")
          expect(result.email).to eq("awesome@example.com")
        }.to change { UserAssociatedAccount.count }.by(1)
        expect(UserAssociatedAccount.last.user).to eq(nil)
        expect(UserAssociatedAccount.last.info["nickname"]).to eq("IAmGroot")
      end

      it 'works if there is already an association with the target account' do
        user = Fabricate(:user, email: "awesome@example.com")
        result = authenticator.after_authenticate(hash)
        expect(result.user.id).to eq(user.id)
      end
    end

    describe "avatar on update" do
      let(:user) { Fabricate(:user) }
      let!(:associated) { UserAssociatedAccount.create!(user: user, provider_name: 'myauth', provider_uid: "1234") }

      it "schedules the job upon update correctly" do
        # No image supplied, do not schedule
        expect { result = authenticator.after_authenticate(hash) }
          .to change { Jobs::DownloadAvatarFromUrl.jobs.count }.by(0)

        # Image supplied, schedule
        expect { result = authenticator.after_authenticate(hash.deep_merge(info: { image: "https://some.domain/image.jpg" })) }
          .to change { Jobs::DownloadAvatarFromUrl.jobs.count }.by(1)

        # User already has profile picture, don't schedule
        user.user_avatar = Fabricate(:user_avatar, custom_upload: Fabricate(:upload))
        user.save!
        expect { result = authenticator.after_authenticate(hash.deep_merge(info: { image: "https://some.domain/image.jpg" })) }
          .to change { Jobs::DownloadAvatarFromUrl.jobs.count }.by(0)
      end
    end

    describe "profile on update" do
      let(:user) { Fabricate(:user) }
      let!(:associated) { UserAssociatedAccount.create!(user: user, provider_name: 'myauth', provider_uid: "1234") }

      it "updates the user's location and bio, unless already set" do
        { description: :bio_raw, location: :location }.each do |auth_hash_key, profile_key|
          user.user_profile.update(profile_key => "Initial Value")
          # No value supplied, do not overwrite
          expect { result = authenticator.after_authenticate(hash) }
            .not_to change { user.user_profile.reload; user.user_profile[profile_key] }

          # Value supplied, still do not overwrite
          expect { result = authenticator.after_authenticate(hash.deep_merge(info: { auth_hash_key => "New Value" })) }
            .not_to change { user.user_profile.reload; user.user_profile[profile_key] }

          # User has not set a value, so overwrite
          user.user_profile.update(profile_key => "")
          authenticator.after_authenticate(hash.deep_merge(info: { auth_hash_key => "New Value" }))
          user.user_profile.reload
          expect(user.user_profile[profile_key]).to eq("New Value")
        end
      end
    end

    describe "avatar on create" do
      let(:user) { Fabricate(:user) }
      let!(:association) { UserAssociatedAccount.create!(provider_name: 'myauth', provider_uid: "1234") }

      it "doesn't schedule with no image" do
        expect { result = authenticator.after_create_account(user, extra_data: create_hash) }
          .to change { Jobs::DownloadAvatarFromUrl.jobs.count }.by(0)
      end

      it "schedules with image" do
        association.info["image"] = "https://some.domain/image.jpg"
        association.save!
        expect { result = authenticator.after_create_account(user, extra_data: create_hash) }
          .to change { Jobs::DownloadAvatarFromUrl.jobs.count }.by(1)
      end
    end

    describe "profile on create" do
      let(:user) { Fabricate(:user) }
      let!(:association) { UserAssociatedAccount.create!(provider_name: 'myauth', provider_uid: "1234") }

      it "doesn't explode without profile" do
        authenticator.after_create_account(user, extra_data: create_hash)
      end

      it "works with profile" do
        association.info["location"] = "DiscourseVille"
        association.info["description"] = "Online forum expert"
        association.save!
        authenticator.after_create_account(user, extra_data: create_hash)
        expect(user.user_profile.bio_raw).to eq("Online forum expert")
        expect(user.user_profile.location).to eq("DiscourseVille")
      end
    end
  end

  describe 'description_for_user' do
    let(:user) { Fabricate(:user) }

    it 'returns empty string if no entry for user' do
      expect(authenticator.description_for_user(user)).to eq("")
    end

    it 'returns correct information' do
      association = UserAssociatedAccount.create!(user: user, provider_name: 'myauth', provider_uid: "1234", info: { nickname: "somenickname", email: "test@domain.tld", name: "bestname" })
      expect(authenticator.description_for_user(user)).to eq('test@domain.tld')
      association.update(info: { nickname: "somenickname", name: "bestname" })
      expect(authenticator.description_for_user(user)).to eq('somenickname')
      association.update(info: { nickname: "bestname" })
      expect(authenticator.description_for_user(user)).to eq('bestname')
    end
  end

  describe 'revoke' do
    let(:user) { Fabricate(:user) }

    it 'raises exception if no entry for user' do
      expect { authenticator.revoke(user) }.to raise_error(Discourse::NotFound)
    end

    context "with valid record" do
      before do
        UserAssociatedAccount.create!(user: user, provider_name: 'myauth', provider_uid: "1234", info: { name: "somename" })
      end

      it 'revokes correctly' do
        expect(authenticator.description_for_user(user)).to eq("somename")
        expect(authenticator.can_revoke?).to eq(true)
        expect(authenticator.revoke(user)).to eq(true)

        expect(authenticator.description_for_user(user)).to eq("")
      end
    end
  end

end
