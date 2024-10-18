# frozen_string_literal: true

RSpec.describe Chat::SearchChatable do
  describe ".call" do
    subject(:result) { described_class.call(params) }

    fab!(:current_user) { Fabricate(:user, username: "bob-user") }
    fab!(:sam) { Fabricate(:user, username: "sam-user") }
    fab!(:charlie) { Fabricate(:user, username: "charlie-user") }
    fab!(:alain) { Fabricate(:user, username: "alain-user") }
    fab!(:group_1) { Fabricate(:group, name: "awesome-group") }
    fab!(:group_2) { Fabricate(:group) }
    fab!(:channel_1) { Fabricate(:chat_channel, name: "bob-channel") }
    fab!(:channel_2) { Fabricate(:direct_message_channel, users: [current_user, sam]) }
    fab!(:channel_3) { Fabricate(:direct_message_channel, users: [current_user, sam, charlie]) }
    fab!(:channel_4) { Fabricate(:direct_message_channel, users: [sam, charlie]) }
    fab!(:channel_5) { Fabricate(:direct_message_channel, users: [current_user, charlie, alain]) }

    let(:guardian) { Guardian.new(current_user) }
    let(:term) { "" }
    let(:include_users) { false }
    let(:include_groups) { false }
    let(:include_category_channels) { false }
    let(:include_direct_message_channels) { false }
    let(:excluded_memberships_channel_id) { nil }
    let(:params) do
      {
        guardian: guardian,
        term: term,
        include_users: include_users,
        include_groups: include_groups,
        include_category_channels: include_category_channels,
        include_direct_message_channels: include_direct_message_channels,
        excluded_memberships_channel_id: excluded_memberships_channel_id,
      }
    end

    before do
      SiteSetting.direct_message_enabled_groups = Group::AUTO_GROUPS[:everyone]
      # simpler user search without having to worry about user search data
      SiteSetting.enable_names = false
      channel_1.add(current_user)
    end

    context "when all steps pass" do
      it { is_expected.to run_successfully }

      it "cleans the term" do
        params[:term] = "#bob"
        expect(result.contract.term).to eq("bob")

        params[:term] = "@bob"
        expect(result.contract.term).to eq("bob")
      end

      it "fetches user memberships" do
        expect(result.memberships).to contain_exactly(
          channel_1.membership_for(current_user),
          channel_2.membership_for(current_user),
          channel_3.membership_for(current_user),
          channel_5.membership_for(current_user),
        )
      end

      context "when including users" do
        let(:include_users) { true }

        it "fetches users" do
          expect(result.users).to include(current_user, sam, charlie, alain)
        end

        it "can filter usernames" do
          params[:term] = "sam"

          expect(result.users).to contain_exactly(sam)
        end

        it "can filter users with a membership to a specific channel" do
          params[:excluded_memberships_channel_id] = channel_1.id

          expect(result.users).to_not include(current_user)
        end

        context "when chat_allowed_bot_user_ids modifier exists" do
          fab!(:bot_1) { Fabricate(:user, id: -500) }
          fab!(:bot_2) { Fabricate(:user, id: -501) }

          it "alters the users returned" do
            modifier_block = Proc.new { [bot_2.id] }
            plugin_instance = Plugin::Instance.new
            plugin_instance.register_modifier(:chat_allowed_bot_user_ids, &modifier_block)

            expect(result.users).to_not include(bot_1)
            expect(result.users).to include(bot_2)
            expect(result.users).to include(current_user, sam, charlie, alain)
          ensure
            DiscoursePluginRegistry.unregister_modifier(
              plugin_instance,
              :chat_allowed_bot_user_ids,
              &modifier_block
            )
          end
        end
      end

      context "when not including users" do
        let(:include_users) { false }

        it "doesn’t fetch users" do
          expect(result.users).to be_nil
        end
      end

      context "when including groups" do
        let(:include_groups) { true }

        it "fetches groups" do
          expect(result.groups).to include(group_1, group_2)
        end

        it "can filter groups by name" do
          params[:term] = "awesome-group"
          expect(result.groups).to contain_exactly(group_1)
        end

        it "excludes groups not matching the search term" do
          params[:term] = "nonexistent"
          expect(result.groups).to be_empty
        end
      end

      context "when not including groups" do
        let(:include_groups) { false }

        it "doesn’t fetch groups" do
          expect(result.groups).to be_nil
        end
      end

      context "when including category channels" do
        let(:include_category_channels) { true }

        it "fetches category channels" do
          expect(result.category_channels).to include(channel_1)
        end

        it "can filter titles" do
          searched_channel = Fabricate(:chat_channel, name: "beaver")
          params[:term] = "beaver"

          expect(result.category_channels).to contain_exactly(searched_channel)
        end

        it "can filter slugs" do
          searched_channel = Fabricate(:chat_channel, name: "beaver", slug: "something")
          params[:term] = "something"

          expect(result.category_channels).to contain_exactly(searched_channel)
        end

        it "doesn’t include category channels you can't access" do
          Fabricate(:private_category_channel)

          expect(result.category_channels).to contain_exactly(channel_1)
        end
      end

      context "when not including category channels" do
        let(:include_category_channels) { false }

        it "doesn’t fetch category channels" do
          expect(result.category_channels).to be_nil
        end
      end

      context "when including direct message channels" do
        let(:include_direct_message_channels) { true }

        it "fetches direct message channels" do
          expect(result.direct_message_channels).to contain_exactly(channel_2, channel_3, channel_5)
        end

        it "doesn’t fetches inaccessible direct message channels" do
          expect(result.direct_message_channels).to_not include(channel_4)
        end

        it "can filter by title" do
          searched_channel =
            Fabricate(:direct_message_channel, users: [current_user, sam, charlie], name: "koala")
          params[:term] = "koala"

          expect(result.direct_message_channels).to contain_exactly(searched_channel)
        end

        it "can filter by slug" do
          searched_channel =
            Fabricate(
              :direct_message_channel,
              users: [current_user, sam, charlie],
              slug: "capybara",
            )
          params[:term] = "capybara"

          expect(result.direct_message_channels).to contain_exactly(searched_channel)
        end

        it "can filter by users" do
          cedric = Fabricate(:user, username: "cedric")
          searched_channel =
            Fabricate(:direct_message_channel, users: [current_user, cedric], slug: "capybara")
          searched_channel.add(cedric)
          params[:term] = "cedric"

          expect(result.direct_message_channels).to contain_exactly(searched_channel)
        end

        context "when also includes users" do
          let(:include_users) { true }

          it "excludes one to one direct message channels with user" do
            expect(result.users).to include(sam)
            expect(result.direct_message_channels).to contain_exactly(channel_3, channel_5)
          end
        end
      end

      context "when not including direct message channels" do
        let(:include_direct_message_channels) { false }

        it "doesn’t fetch direct message channels" do
          expect(result.direct_message_channels).to be_nil
        end
      end
    end
  end
end
