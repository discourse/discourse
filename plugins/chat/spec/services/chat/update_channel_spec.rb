# frozen_string_literal: true

RSpec.describe Chat::UpdateChannel do
  subject(:result) { described_class.call(params:, **dependencies) }

  fab!(:channel) { Fabricate(:chat_channel) }
  fab!(:current_user) { Fabricate(:admin) }
  fab!(:upload) { Fabricate(:upload) }

  let(:guardian) { Guardian.new(current_user) }
  let(:params) do
    {
      channel_id: channel.id,
      name: "cool channel",
      description: "a channel description",
      slug: "snail",
      allow_channel_wide_mentions: true,
      auto_join_users: false,
      icon_upload_id: upload.id,
    }
  end
  let(:dependencies) { { guardian: } }

  context "when the user cannot edit the channel" do
    fab!(:current_user) { Fabricate(:user) }

    it { is_expected.to fail_a_policy(:check_channel_permission) }
  end

  context "when channel is a category one" do
    context "when a valid user provides valid params" do
      let(:message) do
        MessageBus
          .track_publish(Chat::Publisher::CHANNEL_EDITS_MESSAGE_BUS_CHANNEL) { result }
          .first
      end

      it { is_expected.to run_successfully }

      it "updates the channel accordingly" do
        result
        expect(channel.reload).to have_attributes(
          name: "cool channel",
          slug: "snail",
          description: "a channel description",
          allow_channel_wide_mentions: true,
          auto_join_users: false,
          icon_upload_id: upload.id,
        )
      end

      it "publishes a MessageBus message" do
        expect(message.data).to eq(
          {
            chat_channel_id: channel.id,
            name: "cool channel",
            description: "a channel description",
            slug: "snail",
          },
        )
      end

      describe "name" do
        context "when blank" do
          before { params[:name] = "" }

          it "nils out the name" do
            result
            expect(channel.reload.name).to be_nil
          end
        end
      end

      describe "description" do
        context "when blank" do
          before do
            channel.update!(description: "something")
            params[:description] = ""
          end

          it "nils out the description" do
            result
            expect(channel.reload.description).to be_nil
          end
        end
      end

      describe "#auto_join_users" do
        context "when set to 'true'" do
          before do
            channel.update!(auto_join_users: false)
            params[:auto_join_users] = true
          end

          it "updates the model accordingly" do
            result
            expect(channel.reload).to have_attributes(auto_join_users: true)
          end

          it "auto joins users" do
            ::Chat::AutoJoinChannels.expects(:call).with(params: { channel_id: channel.id })
            result
          end
        end
      end

      describe "threading_enabled" do
        context "when true" do
          before { params[:threading_enabled] = true }

          it "changes the value to true" do
            expect { result }.to change { channel.reload.threading_enabled }.from(false).to(true)
          end

          it "enqueues a job to mark all threads in the channel as read" do
            expect_enqueued_with(
              job: Jobs::Chat::MarkAllChannelThreadsRead,
              args: {
                channel_id: channel.id,
              },
            ) { result }
          end
        end

        context "when false" do
          before { params[:threading_enabled] = false }

          it "changes the value to false" do
            channel.update!(threading_enabled: true)

            expect { result }.to change { channel.reload.threading_enabled }.from(true).to(false)
          end

          it "does not enqueue a job to mark all threads in the channel as read" do
            expect_not_enqueued_with(
              job: Jobs::Chat::MarkAllChannelThreadsRead,
              args: {
                channel_id: channel.id,
              },
            ) { result }
          end
        end
      end

      describe "#update_site_settings" do
        before do
          SiteSetting.chat_threads_enabled = false
          params[:threading_enabled] = true
        end

        it "sets chat_threads_enabled to true" do
          expect { result }.to change { SiteSetting.chat_threads_enabled }.from(false).to(true)
        end
      end
    end
  end
end
