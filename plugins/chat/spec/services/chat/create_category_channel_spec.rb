# frozen_string_literal: true

RSpec.describe Chat::CreateCategoryChannel do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of :category_id }
    it { is_expected.to validate_length_of(:name).is_at_most(SiteSetting.max_topic_title_length) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:current_user) { Fabricate(:admin) }
    fab!(:category)
    let(:category_id) { category.id }

    let(:name) { "cool channel" }
    let(:icon_upload_id) { 2 }
    let(:guardian) { Guardian.new(current_user) }
    let(:params) { { category_id:, name: name, icon_upload_id: icon_upload_id } }
    let(:dependencies) { { guardian: } }

    context "when public channels are disabled" do
      fab!(:current_user) { Fabricate(:user) }

      before { SiteSetting.enable_public_channels = false }

      it { is_expected.to fail_a_policy(:public_channels_enabled) }
    end

    context "when the current user cannot make a channel" do
      fab!(:current_user) { Fabricate(:user) }

      it { is_expected.to fail_a_policy(:can_create_channel) }
    end

    context "when the current user can make a channel" do
      context "when there is already a channel for the category with the same name" do
        fab!(:old_channel) { Fabricate(:chat_channel, chatable: category, name: "old channel") }
        let(:params) { { guardian: guardian, category_id: category_id, name: "old channel" } }

        it { is_expected.to fail_a_policy(:category_channel_does_not_exist) }
      end

      context "when the category does not exist" do
        before { category.destroy! }

        it { is_expected.to fail_to_find_a_model(:category) }
      end

      context "when all steps pass" do
        it { is_expected.to run_successfully }

        it "creates the channel" do
          expect { result }.to change { Chat::Channel.count }.by(1)
          expect(result.channel).to have_attributes(
            chatable: category,
            name: name,
            slug: "cool-channel",
            icon_upload_id: icon_upload_id,
          )
        end

        it "creates a membership for the user" do
          expect { result }.to change { Chat::UserChatChannelMembership.count }.by(1)
          expect(result.membership).to have_attributes(
            user: current_user,
            chat_channel: result.channel,
            following: true,
          )
        end

        it "does not enforce automatic memberships" do
          Chat::AutoJoinChannels.expects(:call).never
          result
        end

        context "when the slug is already in use" do
          fab!(:channel) { Fabricate(:chat_channel, chatable: category, slug: "in-use") }
          let(:params) { { guardian: guardian, category_id: category_id, slug: "in-use" } }

          it { is_expected.to fail_with_an_invalid_model(:channel) }
        end

        context "if auto_join_users is blank" do
          let(:params) { { guardian: guardian, category_id: category_id, auto_join_users: "" } }

          it "defaults to false" do
            Chat::AutoJoinChannels.expects(:call).never
            result
          end
        end

        context "if auto_join_users is true" do
          let(:params) { { guardian: guardian, category_id: category_id, auto_join_users: "true" } }

          it "enforces automatic memberships" do
            Chat::AutoJoinChannels.expects(:call).once
            result
          end
        end

        describe "threading_enabled" do
          context "when true" do
            it "sets threading_enabled to true" do
              params[:threading_enabled] = true
              expect(result.channel.threading_enabled).to eq(true)
            end
          end

          context "when blank" do
            it "sets threading_enabled to false" do
              params[:threading_enabled] = nil
              expect(result.channel.threading_enabled).to eq(false)
            end
          end

          context "when false" do
            it "sets threading_enabled to false" do
              params[:threading_enabled] = false
              expect(result.channel.threading_enabled).to eq(false)
            end
          end
        end
      end
    end
  end
end
