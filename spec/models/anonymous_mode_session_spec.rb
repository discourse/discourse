# frozen_string_literal: true

RSpec.describe AnonymousModeSession do
  fab!(:master, :user)
  fab!(:shadow, :user)
  let(:original) { UserAuthToken.generate!(user_id: master.id) }

  def exchange(source, to:)
    master.with_credential_lock do
      source.lock!
      successor = UserAuthToken.generate!(user_id: to.id)
      AnonymousModeSession.exchange!(source, successor, master: master)
      successor
    end
  end

  describe ".exchange!" do
    it "cascades a bulk deletion through only the deleted login's session and proofs" do
      intermediate = exchange(original, to: shadow)
      current = exchange(intermediate, to: master)
      other = UserAuthToken.generate!(user_id: master.id)
      other_current = exchange(other, to: shadow)

      proofs = RetiredUserAuthToken.where(anonymous_mode_session_id: original.id)
      expect(proofs.ids).to contain_exactly(original.id, intermediate.id)

      UserAuthToken.where(id: current.id).delete_all

      expect(AnonymousModeSession.exists?(original.id)).to be(false)
      expect(proofs).to be_empty
      expect(RetiredUserAuthToken.find(other.id).user_auth_token).to eq(other_current)
    end
  end

  describe "RetiredUserAuthToken.revoke_by_cookie" do
    it "revokes the successor with the previous cookie of a rotated source token" do
      previous_cookie = original.unhashed_auth_token
      UserAuthToken.lookup(previous_cookie, seen: true)
      expect(original.rotate!).to be(true)
      successor = exchange(original, to: shadow)
      expect(UserAuthToken.lookup(successor.unhashed_auth_token)).to eq(successor)

      RetiredUserAuthToken.revoke_by_cookie(previous_cookie)

      expect(UserAuthToken.exists?(successor.id)).to be(false)
    end
  end

  describe "UserAuthToken.for_device_list" do
    it "marks the same login current after exchange without exposing master devices to the shadow" do
      first_shadow = exchange(original, to: shadow)
      intermediate = exchange(first_shadow, to: master)
      login_id = UserAuthToken.lookup(intermediate.unhashed_auth_token).login_id
      current = exchange(intermediate, to: shadow)
      other = UserAuthToken.generate!(user_id: master.id)

      master_devices = UserAuthToken.for_device_list(master, current_login_id: login_id)
      expect(master_devices.pluck(:device_id, :current_device)).to contain_exactly(
        [original.id, true],
        [other.id, false],
      )

      shadow_devices = UserAuthToken.for_device_list(shadow, current_login_id: login_id)
      expect(shadow_devices.pluck(:device_id, :current_device)).to contain_exactly(
        [current.id, true],
      )
      expect {
        UserAuthToken.revoke_device!(shadow, current.id, current_login_id: login_id)
      }.to raise_error(Discourse::InvalidParameters)
    end
  end

  describe "UserAuthToken.cleanup!" do
    it "rejects an expired v0 cookie and preserves the device ID for remote revocation after cleanup" do
      SiteSetting.maximum_session_age = 1
      freeze_time
      expired_cookie = original.unhashed_auth_token
      freeze_time 45.minutes.from_now
      intermediate = exchange(original, to: shadow)
      successor = exchange(intermediate, to: master)
      freeze_time 30.minutes.from_now

      expect(RetiredUserAuthToken.exists?(original.id)).to be(true)
      RetiredUserAuthToken.revoke_by_cookie(expired_cookie)
      expect(UserAuthToken.lookup(successor.unhashed_auth_token)).to eq(successor)

      UserAuthToken.cleanup!

      proofs = RetiredUserAuthToken.where(anonymous_mode_session_id: original.id)
      expect(proofs.ids).to contain_exactly(intermediate.id)
      devices = UserAuthToken.for_device_list(master)
      expect(devices.pluck(:device_id)).to contain_exactly(original.id)
      remote = UserAuthToken.generate!(user_id: master.id)
      UserAuthToken.revoke_device!(master, original.id, current_login_id: remote.id)
      expect(UserAuthToken.exists?(successor.id)).to be(false)
      expect(UserAuthToken.lookup(remote.unhashed_auth_token)).to eq(remote)
    end
  end
end
