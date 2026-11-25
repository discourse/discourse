# frozen_string_literal: true

RSpec.describe User, "#with_credential_lock" do
  it "yields persisted identity state without discarding unsaved changes on the caller" do
    user = Fabricate(:user, name: "Persisted")
    user.name = "Unsaved"

    expect { |block| user.with_credential_lock(&block) }.to yield_with_args(
      have_attributes(id: user.id, name: "Persisted"),
    )
    expect(user.name).to eq("Unsaved")
  end

  it "rechecks a shadow's cached master and yields nil once the master is gone" do
    master = Fabricate(:user)
    shadow = Fabricate(:user)
    AnonymousUser.create!(user: shadow, master_user: master, active: false)
    expect(shadow.master_user).to eq(master)
    master.update!(name: "Updated master")

    expect { |block| shadow.with_credential_lock(&block) }.to yield_with_args(
      have_attributes(id: master.id, name: "Updated master"),
    )

    master.destroy!

    expect { |block| shadow.with_credential_lock(&block) }.to yield_with_args(nil)
  end

  context "with independent database connections" do
    self.use_transactional_tests = false

    let!(:master) { Fabricate(:user) }
    let!(:shadow) { Fabricate(:user) }

    before { AnonymousUser.create!(user: shadow, master_user: master, active: false) }

    after do
      shadow.reload.destroy!
      master.reload.destroy!
      UserAuthTokenLog.where(user_id: [master.id, shadow.id]).delete_all
    end

    # The checked-out connection owns the master lock. The save must time out
    # acquiring it without having written either the shadow or its password.
    def expect_master_locked_before_writes
      pool = User.connection_pool
      blocker = pool.checkout(2)
      blocker.transaction do
        blocker.execute("SET LOCAL lock_timeout = '1s'")
        blocker.execute("SELECT id FROM users WHERE id = #{master.id} FOR UPDATE")
        queries =
          track_sql_queries do
            expect do
              User.transaction do
                User.connection.execute("SET LOCAL lock_timeout = '200ms'")
                yield
              end
            end.to raise_error(ActiveRecord::LockWaitTimeout)
          end
        expect(queries.grep(/UPDATE\s+"?(?:users|user_passwords)"?\s+SET/i)).to be_empty
      end
    ensure
      pool.checkin(blocker) if blocker
    end

    it "locks the master before saving changes to the shadow and its password" do
      expect_master_locked_before_writes do
        shadow.update!(name: "Updated shadow", password: SecureRandom.hex)
      end
    end

    it "locks the master before password writes even when validations are skipped" do
      shadow.password = SecureRandom.hex
      expect_master_locked_before_writes { shadow.save!(validate: false) }
    end

    it "locks the master before anonymization saves the shadow's username" do
      expect_master_locked_before_writes { UserAnonymizer.make_anonymous(shadow) }
    end

    it "holds the master lock until the outer password-change transaction commits" do
      pool = User.connection_pool
      observer = pool.checkout(2)
      probe = "SELECT id FROM users WHERE id = #{master.id} FOR UPDATE NOWAIT"
      User.transaction do
        shadow.update!(password: SecureRandom.hex)
        expect { observer.execute(probe) }.to raise_error(ActiveRecord::LockWaitTimeout)
      end
      expect { observer.execute(probe) }.not_to raise_error
    ensure
      pool.checkin(observer) if observer
    end

    it "sees revocation committed by another connection despite earlier browser authentication" do
      freeze_time
      token = UserAuthToken.generate!(user_id: shadow.id)
      cookie = create_auth_cookie(token: token.unhashed_auth_token, user_id: shadow.id)
      env = create_request_env(path: "/").merge("HTTP_COOKIE" => "_t=#{cookie}")
      provider = Auth::DefaultCurrentUserProvider.new(env)
      master_id = master.id

      User.cache do
        expect(provider.current_user).to eq(shadow)
        expect(provider.authenticated_session_user).to eq(shadow)
        Thread
          .new do
            User.connection_pool.with_connection { User.find(master_id).revoke_family_sessions! }
          end
          .value

        shadow.with_credential_lock { expect(provider.authenticated_session_user).to be_nil }
      end
    end

    def sign_in_device
      device = ActionDispatch::Integration::Session.new(Rails.application)
      device.host! "test.localhost"
      device.get "/session/#{master.encoded_username}/become", params: { redirect: "false" }
      expect(device.response).to be_successful
      device
    end

    it "finishes an authenticated logout after the intermediate cookie and its proof have expired" do
      SiteSetting.allow_anonymous_mode = true
      SiteSetting.anonymous_posting_allowed_groups = Group::AUTO_GROUPS[:logged_in_users].to_s
      SiteSetting.log_out_strict = false
      SiteSetting.maximum_session_age = 1
      freeze_time
      shadow.reload.anonymous_user_master.update!(active: true)

      browser = sign_in_device
      original_id = master.user_auth_tokens.sole.id
      2.times do
        browser.post "/u/toggle-anon.json"
        expect(browser.response).to be_successful
      end

      freeze_time 59.minutes.from_now
      other_device = sign_in_device
      cookie = Rack::Utils.escape(browser.cookies["_t"])
      env = create_request_env(path: "/").merge("HTTP_COOKIE" => "_t=#{cookie}")
      request = ActionDispatch::Request.new(env)
      logout = Auth::DefaultCurrentUserProvider.new(env)
      User.connection_pool.with_connection do
        expect(Auth::DefaultCurrentUserProvider.new(env).current_user).to eq(master)
        Thread
          .new { User.connection_pool.with_connection { browser.post "/u/toggle-anon.json" } }
          .value
        expect(browser.response).to be_successful
        freeze_time 2.minutes.from_now
        UserAuthToken.cleanup!
        expect(RetiredUserAuthToken.where(anonymous_mode_session_id: original_id)).to be_empty
        browser.get "/session/current.json"
        expect(browser.response.parsed_body.dig("current_user", "id")).to eq(shadow.id)

        login_id = Guardian.new(master, request).current_login_id
        expect(login_id).to eq(original_id)
        expect {
          UserAuthToken.revoke_device!(master, original_id, current_login_id: login_id)
        }.to raise_error(Discourse::InvalidParameters)
        logout.log_off_user(env["rack.session"], request.cookie_jar)
      end

      browser.get "/session/current.json"
      expect(browser.response.status).to eq(404)
      other_device.get "/session/current.json"
      expect(other_device.response.parsed_body.dig("current_user", "id")).to eq(master.id)
    end

    it "serializes historical-shadow exchanges and master revocation on the same database row" do
      shadow_id = shadow.id
      locked = Queue.new
      release = Queue.new
      pool = ActiveRecord::Base.connection_pool
      exchange =
        Thread.new do
          pool.with_connection do
            User
              .find(shadow_id)
              .with_credential_lock do
                locked << true
                raise "Timed out releasing credential lock" unless release.pop(timeout: 10)
              end
          end
        end

      begin
        expect(locked.pop(timeout: 5)).to eq(true)
        expect do
          User.transaction do
            User.connection.execute("SET LOCAL lock_timeout = '100ms'")
            master.revoke_family_sessions!
          end
        end.to raise_error(ActiveRecord::LockWaitTimeout)
      ensure
        release << true
        exchange.kill unless exchange.join(5)
        exchange.join
      end

      expect { master.revoke_family_sessions! }.not_to raise_error
    end
  end
end
