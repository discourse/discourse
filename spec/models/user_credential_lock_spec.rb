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

    it "locks before password validation can upgrade an existing hash" do
      password = "myawesomepassword"
      algorithm = "$pbkdf2-sha256$i=5,l=32$"
      salt = shadow.user_password.password_salt
      hash = PasswordHasher.hash_password(password:, salt:, algorithm:)
      shadow.user_password.update_columns(password_hash: hash, password_algorithm: algorithm)

      expect_master_locked_before_writes { shadow.update!(password: password) }
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
            User.connection_pool.with_connection { User.find(master_id).revoke_all_credentials! }
          end
          .value

        shadow.with_credential_lock { expect(provider.authenticated_session_user).to be_nil }
      end
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
            master.revoke_all_credentials!
          end
        end.to raise_error(ActiveRecord::LockWaitTimeout)
      ensure
        release << true
        exchange.kill unless exchange.join(5)
        exchange.join
      end

      expect { master.revoke_all_credentials! }.not_to raise_error
    end
  end
end
