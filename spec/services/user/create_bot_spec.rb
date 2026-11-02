# frozen_string_literal: true

RSpec.describe User::CreateBot do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:username) }
    it { is_expected.to allow_values(*(0..4), *%w[0 1 2 3 4]).for(:trust_level) }

    it { is_expected.not_to allow_values(nil, -1, 5, "").for(:trust_level) }

    it "requires a name when full names are required at signup" do
      SiteSetting.full_name_requirement = "required_at_signup"

      [{}, { name: nil }, { name: "" }, { name: " " }].each do |name_attributes|
        contract = described_class.new(username: "release_helper", **name_attributes)

        expect(contract).not_to be_valid
        expect(contract.errors.of_kind?(:name, :blank)).to eq(true)
      end
    end

    it "allows an omitted or blank name when full names are optional at signup" do
      SiteSetting.full_name_requirement = "optional_at_signup"

      names = [{}, { name: nil }, { name: "" }, { name: " " }, { name: "Release helper" }]
      names.each do |name_attributes|
        contract = described_class.new(username: "release_helper", **name_attributes)

        expect(contract).to be_valid
      end
    end

    it "defaults to the site's current trust level" do
      SiteSetting.default_trust_level = 2

      contract = described_class.new(username: "release_helper")

      expect(contract).to be_valid
      expect(contract.trust_level).to eq(2)
    end

    context "with an API key" do
      subject(:contract) do
        described_class.new(username: "release_helper", api_key: api_key_attributes)
      end

      let(:api_key_attributes) { { description: "Release key", scope_mode: "global" } }

      it { is_expected.to be_valid }

      it "allows an omitted description" do
        api_key_attributes.delete(:description)

        expect(contract).to be_valid
      end

      it "limits the description length" do
        api_key_attributes[:description] = "x" * 256

        expect(contract).not_to be_valid
        expect(contract.errors).to include(:"api_key.description")
      end

      it "requires a known scope mode" do
        api_key_attributes[:scope_mode] = "everything"

        expect(contract).not_to be_valid
        expect(contract.errors).to include(:"api_key.scope_mode")
      end
    end
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:actor, :admin)

    let(:params) { { name: "Release helper", username: "release_helper", trust_level: 2 } }
    let(:dependencies) { { guardian: actor.guardian } }

    context "when the contract is invalid" do
      let(:params) { { username: "" } }

      it "rejects invalid input without reserving a bot ID" do
        expect { result }.not_to change { PluginStore.get("core", BotUser::FLOOR_KEY) }
        expect(result).to fail_a_contract
      end
    end

    context "when the actor is anonymous" do
      let(:dependencies) { { guardian: Guardian.new } }

      it { is_expected.to fail_a_policy(:can_create_bot) }
    end

    context "when the actor is a regular user" do
      fab!(:actor, :user)

      it "rejects creation without reserving a bot ID" do
        expect { result }.not_to change { PluginStore.get("core", BotUser::FLOOR_KEY) }
        expect(result).to fail_a_policy(:can_create_bot)
      end
    end

    context "when the actor is a moderator" do
      fab!(:actor, :moderator)

      it { is_expected.to fail_a_policy(:can_create_bot) }
    end

    context "when the site is archived" do
      before { SiteSetting.site_archived = true }

      it "rejects creation without persisting a user" do
        expect { result }.not_to change(User, :count)
        expect(result).to fail_a_policy(:site_not_archived)
      end
    end

    context "when everything is valid" do
      it { is_expected.to run_successfully }

      it "creates an active, approved, non-staff bot without credentials" do
        expect { result }.to change(User, :count).by(1)

        bot = result.user.reload
        expect(bot.id).to be < 0
        expect(bot).to have_attributes(
          username: params[:username],
          name: params[:name],
          trust_level: params[:trust_level],
          admin: false,
          moderator: false,
          active: true,
          approved: true,
          approved_by_id: actor.id,
          password_hash: nil,
        )
        expect(bot.approved_at).to be_present
        expect(bot.email).to match(/\A[0-9a-f]+@does-not-exist\.invalid\z/)
        expect(bot.user_auth_tokens).to be_empty
        expect(bot.api_keys).to be_empty
        expect(bot.user_api_keys).to be_empty
      end

      it "initializes normal user associations and automatic trust-level groups" do
        User.set_callback(:create, :after, :ensure_in_trust_level_group)
        bot = result.user.reload

        expect(bot.user_stat).to be_persisted
        expect(bot.user_option).to be_persisted
        expect(bot.user_profile).to be_persisted
        expect(bot.groups.where(automatic: true).pluck(:name)).to contain_exactly(
          "trust_level_0",
          "trust_level_1",
          "trust_level_2",
        )
      ensure
        User.skip_callback(:create, :after, :ensure_in_trust_level_group)
      end

      it "logs the actor and target as a bot creation staff action" do
        expect { result }.to change {
          UserHistory.where(action: UserHistory.actions[:create_bot]).count
        }.by(1)

        expect(UserHistory.last).to have_attributes(
          action: UserHistory.actions[:create_bot],
          acting_user_id: actor.id,
          target_user_id: result.user.id,
          subject: result.user.username,
        )
      end

      it "generates distinct internal email addresses" do
        second_result =
          described_class.call(params: params.merge(username: "another_helper"), **dependencies)

        expect(second_result).to run_successfully
        expect(result.user.email).not_to eq(second_result.user.email)
      end

      it "queues no signup, invitation, or welcome messages" do
        SiteSetting.send_welcome_message = true
        SiteSetting.send_tl1_welcome_message = true
        SiteSetting.send_tl2_promotion_message = true

        expect { result }.to not_change { Jobs::CriticalUserEmail.jobs.size }
          .and(not_change { Jobs::UserEmail.jobs.size })
          .and(not_change { Jobs::InviteEmail.jobs.size })
          .and(not_change { Jobs::InvitePasswordInstructionsEmail.jobs.size })
          .and(not_change { Jobs::SendSystemMessage.jobs.size })
      end
    end

    context "when an API key is requested" do
      let(:params) do
        {
          username: "release_helper",
          trust_level: 2,
          api_key: {
            description: "Release key",
            scope_mode: "granular",
            scopes: [{ scope_id: "topics:write", topic_id: "1,2" }],
          },
        }
      end

      context "with an unknown scope" do
        before { params[:api_key][:scopes] = [{ scope_id: "topics:explode" }] }

        it "creates neither the bot nor the key" do
          expect { result }.to not_change(User, :count).and(not_change(ApiKey, :count)).and(
            not_change(UserHistory, :count),
          )
          expect(result).to fail_to_find_a_model(:api_key)
        end
      end

      context "with an invalid key" do
        before { params[:api_key][:scopes] = [] }

        it "creates neither the bot nor the key" do
          expect { result }.to not_change(User, :count).and(not_change(ApiKey, :count)).and(
            not_change(UserHistory, :count),
          )
          expect(result).to fail_with_an_invalid_model(:api_key)
        end
      end

      context "when everything is valid" do
        it { is_expected.to run_successfully }

        it "creates a key for the bot with the requested scopes" do
          expect(result.api_key).to have_attributes(
            user: result.user,
            created_by: actor,
            description: "Release key",
            scope_mode: "granular",
          )
          expect(result.api_key).to be_key_available
          expect(result.api_key.api_key_scopes.map(&:attributes)).to contain_exactly(
            include(
              "resource" => "topics",
              "action" => "write",
              "allowed_parameters" => {
                "topic_id" => %w[1 2],
              },
            ),
          )
        end

        context "without a description" do
          before { params[:api_key].delete(:description) }

          it "describes the key with the bot's username" do
            expect(result.api_key.description).to eq("release_helper")
          end
        end

        it "logs the key creation" do
          expect { result }.to change {
            UserHistory.where(action: UserHistory.actions[:api_key_create]).count
          }.by(1)

          expect(UserHistory.last).to have_attributes(
            acting_user_id: actor.id,
            subject: result.api_key.truncated_key,
          )
        end
      end
    end

    it "honors trust level zero when the site default is four" do
      SiteSetting.default_trust_level = 4
      params[:trust_level] = 0

      expect(result).to run_successfully
      expect(result.user.trust_level).to eq(0)
    end

    it "uses the site default when the trust level is omitted" do
      SiteSetting.default_trust_level = 1
      params.delete(:trust_level)

      expect(result).to run_successfully
      expect(result.user.trust_level).to eq(1)
    end

    it "skips signup email policy only for the explicitly created bot" do
      SiteSetting.allowed_email_domains = "company.example"
      ordinary_user = User.new(username: "ordinary_user", email: "human@other.example")

      expect(result).to run_successfully
      expect(ordinary_user).not_to be_valid
      expect(ordinary_user.errors[:primary_email]).to include(I18n.t("user.email.not_allowed"))
    end

    {
      "invalid characters" => "invalid!username",
      "a reserved username" => "reserved_helper",
      "an existing route" => "admin",
      "a username shorter than the site minimum" => "bot",
      "a username longer than the site maximum" => "x" * 21,
    }.each do |description, username|
      it "rejects #{description} without creating a user or audit entry" do
        SiteSetting.reserved_usernames = "reserved_helper"
        SiteSetting.min_username_length = 4
        SiteSetting.max_username_length = 20
        params[:username] = username

        expect { result }.to not_change(User, :count).and(not_change(UserHistory, :count))
        expect(result).to fail_with_an_invalid_model(:user)
        expect(result.user.errors[:username]).to be_present
      end
    end

    it "rejects a case-insensitive duplicate username without creating a user or audit entry" do
      Fabricate(:user, username: params[:username].upcase)

      expect { result }.to not_change(User, :count).and(not_change(UserHistory, :count))
      expect(result).to fail_with_an_invalid_model(:user)
      expect(result.user.errors[:username]).to include(I18n.t("user.username.unique"))
    end

    it "rejects usernames already used by a group" do
      Fabricate(:group, name: params[:username])

      expect { result }.not_to change(User, :count)
      expect(result).to fail_with_an_invalid_model(:user)
    end

    it "enforces the existing full-name length limit" do
      params[:name] = "x" * 256

      expect { result }.not_to change(User, :count)
      expect(result).to fail_with_an_invalid_model(:user)
      expect(result.user.errors[:name]).to be_present
    end

    it "enforces the site's full-name requirement in the contract" do
      SiteSetting.full_name_requirement = "required_at_signup"
      params[:name] = ""

      expect { result }.to not_change(User, :count).and(not_change(UserHistory, :count))
      expect(result).to fail_a_contract
    end
  end
end

RSpec.describe User::CreateBot, ".call" do
  self.use_transactional_tests = false

  let(:actor) { Fabricate(:admin) }
  let(:usernames) do
    token = SecureRandom.hex(3)
    ["race_bot_#{token}_a", "race_bot_#{token}_b"]
  end

  before do
    @saved_floors = PluginStoreRow.where(key: BotUser::FLOOR_KEY).map(&:attributes)
    PluginStoreRow.where(key: BotUser::FLOOR_KEY).delete_all
  end

  after do
    UserHistory.where(acting_user_id: actor.id).delete_all
    User.where(username: usernames, approved_by_id: actor.id).find_each(&:destroy!)
    actor.destroy!
    PluginStoreRow.where(key: BotUser::FLOOR_KEY).delete_all
    PluginStoreRow.insert_all!(@saved_floors) if @saved_floors.present?
  end

  [nil, -5000].each do |floor|
    context "with concurrent creation and #{floor ? "an existing" : "no"} allocation floor" do
      it "creates distinct bots while another creation transaction is still open" do
        PluginStore.set("core", BotUser::FLOOR_KEY, floor) if floor
        actor_id = actor.id
        first_username, second_username = usernames
        first_started = Queue.new
        release_first = Queue.new
        first_result = Queue.new
        second_result = Queue.new
        threads = []
        pool = ActiveRecord::Base.connection_pool
        service_class = described_class
        pause_first =
          lambda do |user|
            if user.username == first_username
              first_started << true
              unless release_first.pop(timeout: 10)
                raise "Timed out waiting to finish the first bot"
              end
            end
          end
        create_bot =
          lambda do |username, result_queue|
            pool.with_connection do |connection|
              connection.execute("SET lock_timeout = '2s'")
              result_queue << service_class.call(
                params: {
                  username: username,
                },
                guardian: User.find(actor_id).guardian,
              )
            ensure
              connection.execute("SET lock_timeout = DEFAULT")
            end
          rescue => exception
            result_queue << exception
          end

        User.set_callback(:create, :before, pause_first)
        pool.release_connection

        begin
          threads << Thread.new { create_bot.call(first_username, first_result) }
          expect(first_started.pop(timeout: 5)).to eq(true)
          threads << Thread.new { create_bot.call(second_username, second_result) }
          second_outcome = second_result.pop(timeout: 5)
          expect(second_outcome).to run_successfully
        ensure
          release_first << true
          threads.each do |thread|
            thread.kill unless thread.join(5)
            thread.join
          end
          User.skip_callback(:create, :before, pause_first)
        end

        first_outcome = first_result.pop(timeout: 1)
        expect(first_outcome).to run_successfully
        expect(second_outcome.user.id).to be < first_outcome.user.id
        expect(User.where(username: usernames).pluck(:username)).to contain_exactly(*usernames)
        expect(
          UserHistory.where(
            acting_user_id: actor_id,
            action: UserHistory.actions[:create_bot],
          ).count,
        ).to eq(2)
      end
    end
  end
end
