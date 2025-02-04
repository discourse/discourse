# frozen_string_literal: true

describe DiscourseAutomation::Scriptable do
  before do
    DiscourseAutomation::Scriptable.add("cats_everywhere") do
      version 1

      placeholder :foo
      placeholder :bar
      placeholder { |fields, automation| "baz-#{automation.id}" }
      placeholder { |fields, automation| ["foo-baz-#{automation.id}"] }

      field :cat, component: :text
      field :dog, component: :text, accepts_placeholders: true, accepted_contexts: ["user"]
      field :bird, component: :text, triggerable: "recurring"

      script { p "script" }

      on_reset { p "on_reset" }
    end

    DiscourseAutomation::Triggerable.add("dog") { field :kind, component: :text }

    DiscourseAutomation::Scriptable.add("only_dogs") { triggerable! :dog, { kind: "good_boy" } }
  end

  fab!(:automation) do
    Fabricate(:automation, script: "cats_everywhere", trigger: DiscourseAutomation::Triggers::TOPIC)
  end

  describe "#fields" do
    it "returns the fields" do
      expect(automation.scriptable.fields).to match_array(
        [
          {
            extra: {
            },
            name: :cat,
            component: :text,
            accepts_placeholders: false,
            triggerable: nil,
            required: false,
            accepted_contexts: [],
          },
          {
            extra: {
            },
            name: :dog,
            component: :text,
            accepts_placeholders: true,
            triggerable: nil,
            required: false,
            accepted_contexts: ["user"],
          },
          {
            extra: {
            },
            name: :bird,
            component: :text,
            accepts_placeholders: false,
            triggerable: "recurring",
            required: false,
            accepted_contexts: [],
          },
        ],
      )
    end
  end

  describe "#script" do
    it "returns the script proc" do
      output = capture_stdout { automation.scriptable.script.call }

      expect(output).to include("script")
    end
  end

  describe "#on_reset" do
    it "returns the on_reset proc" do
      output = capture_stdout { automation.scriptable.on_reset.call }

      expect(output).to include("on_reset")
    end
  end

  describe "#placeholders" do
    it "returns the specified placeholders" do
      expect(automation.scriptable.placeholders).to eq(
        [
          { name: :foo, triggerable: nil },
          { name: :bar, triggerable: nil },
          { name: :"baz-#{automation.id}", triggerable: nil },
          { name: :"foo-baz-#{automation.id}", triggerable: nil },
        ],
      )
    end
  end

  describe "#version" do
    it "returns the specified version" do
      expect(automation.scriptable.version).to eq(1)
    end
  end

  describe ".add" do
    it "adds the script to the list of available scripts" do
      expect(automation.scriptable).to respond_to(:__scriptable_cats_everywhere)
    end
  end

  describe ".all" do
    it "returns the list of available scripts" do
      expect(DiscourseAutomation::Scriptable.all).to include(:__scriptable_cats_everywhere)
    end
  end

  describe ".name" do
    it "returns the name of the script" do
      expect(automation.scriptable.name).to eq("cats_everywhere")
    end
  end

  describe "triggerable!" do
    fab!(:automation) { Fabricate(:automation, script: "only_dogs", trigger: "dog") }

    it "has a forced triggerable" do
      expect(automation.scriptable.forced_triggerable).to eq(
        triggerable: :dog,
        state: {
          kind: "good_boy",
        },
      )
    end

    it "returns the forced triggerable in triggerables" do
      expect(automation.scriptable.triggerables).to eq([:dog])
    end
  end

  describe ".utils" do
    describe ".fetch_report" do
      context "when the report doesn’t exist" do
        it "does nothing" do
          expect(automation.scriptable.utils.fetch_report(:foo)).to eq(nil)
        end
      end

      context "when the report exists" do
        it "returns the data" do
          freeze_time DateTime.parse("2022-02-25")
          Fabricate(:like, user: Fabricate(:user))
          Fabricate(:like, user: Fabricate(:user))

          expect(automation.scriptable.utils.fetch_report(:likes)).to eq(
            "\n|Day|Count|\n|-|-|\n|2022-02-25|2|\n",
          )
        end
      end
    end

    describe ".apply_placeholders" do
      it "replaces the given string by placeholders" do
        input = "hello %%COOL_CAT%% {{cool_cat}}"
        map = { cool_cat: "siberian cat" }
        output = automation.scriptable.utils.apply_placeholders(input, map)
        expect(output).to eq("hello siberian cat siberian cat")
      end

      it "replaces site_title by default" do
        input = "hello {{site_title}}"
        output = automation.scriptable.utils.apply_placeholders(input)
        expect(output).to eq("hello #{SiteSetting.title}")
      end

      context "when using the REPORT key" do
        context "with no filters specified" do
          it "replaces REPORT key" do
            freeze_time DateTime.parse("2022-02-22")
            Fabricate(:like, user: Fabricate(:user))
            Fabricate(:like, user: Fabricate(:user))
            input = "hello %%REPORT=likes%%"

            output = automation.scriptable.utils.apply_placeholders(input, {})
            expect(output).to eq("hello \n|Day|Count|\n|-|-|\n|2022-02-22|2|\n")
          end
        end

        context "with dates specified" do
          it "replaces REPORT key using dates" do
            freeze_time DateTime.parse("2022-02-14")
            group = Fabricate(:group)
            group.add(Fabricate(:user, created_at: DateTime.parse("2022-02-01")))
            group.add(Fabricate(:user, created_at: DateTime.parse("2022-02-12")))
            input = "hello %%REPORT=signups start_date=2022-02-10%%"

            output = automation.scriptable.utils.apply_placeholders(input, {})
            expect(output).to eq("hello \n|Day|Count|\n|-|-|\n|2022-02-12|1|\n")
          end
        end

        context "with filters specified" do
          it "replaces REPORT key using filters" do
            freeze_time DateTime.parse("2022-02-15")
            group = Fabricate(:group)
            group.add(Fabricate(:user))
            Fabricate(:user)
            input = "hello %%REPORT=signups group=#{group.id}%%"

            output = automation.scriptable.utils.apply_placeholders(input, {})
            expect(output).to eq("hello \n|Day|Count|\n|-|-|\n|2022-02-15|1|\n")
          end
        end
      end
    end

    describe ".build_quote" do
      subject(:quote) { DiscourseAutomation::Scriptable::Utils.build_quote(post) }

      fab!(:user) { Fabricate(:user, name: "John Doe", username: "johndoe") }
      fab!(:post) { Fabricate(:post, user: user, raw: "This is a post content", post_number: 1) }

      before do
        SiteSetting.display_name_on_posts = false
        SiteSetting.prioritize_username_in_ux = false
      end

      context "when post is nil" do
        let(:post) { nil } # Define post as nil in this context

        it "returns an empty string" do
          expect(quote).to eq("")
        end
      end

      context "when post.raw is nil" do
        before { post.raw = nil }

        it "returns an empty string" do
          expect(quote).to eq("")
        end
      end

      context "when display_name_on_posts is true and prioritize_username_in_ux is false" do
        before do
          SiteSetting.display_name_on_posts = true
          SiteSetting.prioritize_username_in_ux = false
        end

        it "returns a quote with display name" do
          expect(quote).to eq(
            "[quote=John Doe, post:#{post.post_number}, topic:#{post.topic_id}, username:johndoe]\nThis is a post content\n[/quote]\n\n",
          )
        end
      end

      context "when display_name_on_posts is false or prioritize_username_in_ux is true" do
        it "returns a quote with username" do
          expect(quote).to eq(
            "[quote=johndoe, post:#{post.post_number}, topic:#{post.topic_id}]\nThis is a post content\n[/quote]\n\n",
          )
        end
      end

      context "when full_name is nil and display_name_on_posts is true" do
        before do
          user.update(name: nil)
          SiteSetting.display_name_on_posts = true
          SiteSetting.prioritize_username_in_ux = false
        end

        it "returns a quote with username" do
          expect(quote).to eq(
            "[quote=johndoe, post:#{post.post_number}, topic:#{post.topic_id}]\nThis is a post content\n[/quote]\n\n",
          )
        end
      end

      context "when display_name_on_posts is true and prioritize_username_in_ux is true" do
        before do
          SiteSetting.display_name_on_posts = true
          SiteSetting.prioritize_username_in_ux = true
        end

        it "returns a quote with username prioritized" do
          expect(quote).to eq(
            "[quote=johndoe, post:#{post.post_number}, topic:#{post.topic_id}]\nThis is a post content\n[/quote]\n\n",
          )
        end
      end
    end

    describe ".send_pm" do
      let(:user) { Fabricate(:user) }

      context "when pm is delayed" do
        it "creates a pending pm" do
          expect {
            DiscourseAutomation::Scriptable::Utils.send_pm(
              {
                title: "Tell me and I forget.",
                raw: "Teach me and I remember. Involve me and I learn.",
                target_usernames: Array(user.username),
              },
              delay: 2,
              automation_id: automation.id,
            )
          }.to change { DiscourseAutomation::PendingPm.count }.by(1)
        end
      end

      context "when pm is not delayed" do
        it "creates a pm" do
          expect {
            DiscourseAutomation::Scriptable::Utils.send_pm(
              {
                title: "Tell me and I forget.",
                raw: "Teach me and I remember. Involve me and I learn.",
                target_usernames: Array(user.username),
              },
            )
          }.to change { Post.count }.by(1)
        end
      end

      context "when pm exceeds max_post_length" do
        it "throws an error" do
          SiteSetting.max_post_length = 250

          expect {
            DiscourseAutomation::Scriptable::Utils.send_pm(
              {
                title: "Tell me and I forget.",
                raw: "0123456789" * 25 + "a",
                target_usernames: [user.username],
              },
            )
          }.to raise_error(ActiveRecord::RecordNotSaved)
        end
      end

      context "when pm target_usernames contain an invalid user" do
        it "skips sending if there is only one target" do
          expect {
            DiscourseAutomation::Scriptable::Utils.send_pm(
              {
                title: "Tell me and I forget.",
                raw: "0123456789" * 25 + "a",
                target_usernames: ["non-existent-user"],
              },
            )
          }.not_to change { Topic.count }
        end

        it "sends the pm without the invalid user" do
          expect {
            DiscourseAutomation::Scriptable::Utils.send_pm(
              {
                title: "Tell me and I forget.",
                raw: "0123456789" * 25 + "a",
                target_usernames: ["non-existent-user", user.username],
              },
            )
          }.to change { Topic.count }

          expect(Topic.last.allowed_users).to contain_exactly(Discourse.system_user, user)
        end
      end

      context "when pm target_groups with valid group" do
        it "sends the pm" do
          group = Fabricate(:group)

          expect {
            DiscourseAutomation::Scriptable::Utils.send_pm(
              {
                title: "Tell me and I forget.",
                raw: "0123456789" * 25 + "a",
                target_group_names: [group.name],
              },
            )
          }.to change { Topic.count }

          expect(Topic.last.allowed_groups).to contain_exactly(group)
        end
      end

      context "when pm target_groups contain an invalid group" do
        it "skips sending if there is only one target" do
          expect {
            DiscourseAutomation::Scriptable::Utils.send_pm(
              {
                title: "Tell me and I forget.",
                raw: "0123456789" * 25 + "a",
                target_group_names: ["non-existent-group"],
              },
            )
          }.not_to change { Topic.count }
        end

        it "sends the pm without the invalid group" do
          group = Fabricate(:group)

          expect {
            DiscourseAutomation::Scriptable::Utils.send_pm(
              {
                title: "Tell me and I forget.",
                raw: "0123456789" * 25 + "a",
                target_group_names: ["non-existent-group", group.name],
              },
            )
          }.to change { Topic.count }

          expect(Topic.last.allowed_groups).to contain_exactly(group)
        end
      end

      context "when pm target_emails with valid email" do
        it "sends the pm" do
          expect {
            DiscourseAutomation::Scriptable::Utils.send_pm(
              {
                title: "Private Message Title",
                raw: "0123456789" * 25 + "a",
                target_emails: ["john@doe.com"],
              },
            )
          }.to change { Topic.private_messages.count }
        end

        it "sends shared pm when multiple emails" do
          email_1 = "john@doe.com"
          email_2 = "jane@doe.com"

          expect {
            DiscourseAutomation::Scriptable::Utils.send_pm(
              {
                title: "Private Message Title",
                raw: "0123456789" * 25 + "a",
                target_emails: [email_1, email_2],
              },
            )
          }.to change { Topic.private_messages.count }

          # creates new users if they don't exist
          user_1 = User.find_by_email(email_1)
          user_2 = User.find_by_email(email_2)

          expect(
            Topic.private_messages.first.topic_allowed_users.pluck(:user_id),
          ).to contain_exactly(Discourse.system_user.id, user_1.id, user_2.id)
        end
      end

      context "when pm target_emails contain an invalid email" do
        it "skips sending if there is only one target" do
          expect {
            DiscourseAutomation::Scriptable::Utils.send_pm(
              {
                title: "Private Message Title",
                raw: "0123456789" * 25 + "a",
                target_emails: ["invalid-email"],
              },
            )
          }.not_to change { Topic.private_messages.count }
        end

        it "sends the pm without the invalid email" do
          expect {
            DiscourseAutomation::Scriptable::Utils.send_pm(
              {
                title: "Private Message Title",
                raw: "0123456789" * 25 + "a",
                target_emails: %w[invalid-email john@doe.com],
              },
            )
          }.to change { Topic.private_messages.count }.by(1)

          new_user = User.find_by_email("john@doe.com")
          expect(
            Topic.private_messages.first.topic_allowed_users.pluck(:user_id),
          ).to contain_exactly(Discourse.system_user.id, new_user.id)
        end
      end
    end
  end
end
