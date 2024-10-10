# frozen_string_literal: true

RSpec.describe Chat::CreateMessage do
  describe described_class::Contract, type: :model do
    subject(:contract) { described_class.new(upload_ids: upload_ids) }

    let(:upload_ids) { nil }

    it { is_expected.to validate_presence_of :chat_channel_id }

    context "when uploads are not provided" do
      it { is_expected.to validate_presence_of :message }
    end

    context "when uploads are provided" do
      let(:upload_ids) { "2,3" }

      it { is_expected.not_to validate_presence_of :message }
    end
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, options:, **dependencies) }

    fab!(:user)
    fab!(:other_user) { Fabricate(:user) }
    fab!(:channel) { Fabricate(:chat_channel, threading_enabled: true) }
    fab!(:thread) { Fabricate(:chat_thread, channel: channel) }
    fab!(:upload) { Fabricate(:upload, user: user) }
    fab!(:draft) { Fabricate(:chat_draft, user: user, chat_channel: channel) }

    let(:guardian) { user.guardian }
    let(:content) { "A new message @#{other_user.username_lower}" }
    let(:context_topic_id) { nil }
    let(:context_post_ids) { nil }
    let(:params) do
      {
        chat_channel_id: channel.id,
        message: content,
        upload_ids: [upload.id],
        context_topic_id: context_topic_id,
        context_post_ids: context_post_ids,
      }
    end
    let(:options) { { enforce_membership: false, force_thread: false } }
    let(:dependencies) { { guardian: } }
    let(:message) { result[:message_instance].reload }

    before { channel.add(guardian.user) }

    shared_examples "creating a new message" do
      it "saves the message" do
        expect { result }.to change { Chat::Message.count }.by(1)
        expect(message).to have_attributes(message: content)
      end

      it "cooks the message" do
        expect(message).to be_cooked
      end

      it "creates the excerpt" do
        expect(message).to have_attributes(excerpt: content)
      end

      it "creates mentions" do
        Jobs.run_immediately!
        expect { result }.to change { Chat::Mention.count }.by(1)
      end

      it "cleans the message" do
        params[:message] = "aaaaaaa\n"
        expect(message.message).to eq("aaaaaaa")
      end

      context "when strip_whitespace is disabled" do
        before do
          options[:strip_whitespaces] = false
          params[:message] = "aaaaaaa\n"
        end

        it "doesn't strip newlines" do
          expect(message.message).to eq("aaaaaaa\n")
        end
      end

      context "when coming from a webhook" do
        let(:incoming_webhook) { Fabricate(:incoming_chat_webhook, chat_channel: channel) }

        before { dependencies[:incoming_chat_webhook] = incoming_webhook }

        it "creates a webhook event" do
          expect { result }.to change { Chat::WebhookEvent.count }.by(1)
        end
      end

      it "attaches uploads" do
        expect(message.uploads).to match_array(upload)
      end

      it "deletes drafts" do
        expect { result }.to change { Chat::Draft.count }.by(-1)
      end

      it "publishes the new message" do
        Chat::Publisher.expects(:publish_new!).with(channel, instance_of(Chat::Message), nil)
        result
      end

      context "when process_inline is false" do
        before { options[:process_inline] = false }

        it "enqueues a job to process message" do
          expect_enqueued_with(job: Jobs::Chat::ProcessMessage) { result }
        end
      end

      context "when process_inline is true" do
        before { options[:process_inline] = true }

        it "processes a message inline" do
          Jobs::Chat::ProcessMessage.any_instance.expects(:execute).once
          expect_not_enqueued_with(job: Jobs::Chat::ProcessMessage) { result }
        end
      end

      it "triggers a Discourse event" do
        DiscourseEvent.expects(:trigger).with(
          :chat_message_created,
          instance_of(Chat::Message),
          channel,
          user,
          has_entries(thread: anything, thread_replies_count: anything, context: anything),
        )

        result
      end

      context "when a context is given" do
        let(:context_post_ids) { [1, 2] }
        let(:context_topic_id) { 3 }

        it "triggers a Discourse event with context" do
          DiscourseEvent.expects(:trigger).with(
            :chat_message_created,
            instance_of(Chat::Message),
            channel,
            user,
            has_entries(
              thread: anything,
              thread_replies_count: anything,
              context: {
                post_ids: context_post_ids,
                topic_id: context_topic_id,
              },
            ),
          )

          result
        end
      end

      it "processes the direct message channel" do
        Chat::Action::PublishAndFollowDirectMessageChannel.expects(:call).with(
          channel_membership: membership,
        )
        result
      end
    end

    shared_examples "a message in a thread" do
      let(:thread_membership) { Chat::UserChatThreadMembership.find_by(user: user) }
      let(:original_user) { thread.original_message_user }

      before do
        Chat::UserChatThreadMembership.where(user: original_user).delete_all
        Discourse.redis.flushdb # for replies count cache
      end

      it "increments the replies count" do
        result
        expect(thread.replies_count_cache).to eq(1)
      end

      it "adds current user to the thread" do
        expect { result }.to change { Chat::UserChatThreadMembership.where(user: user).count }.by(1)
      end

      it "sets last_read_message on the thread membership" do
        result
        expect(thread_membership.last_read_message).to eq message
      end

      it "adds original message user to the thread" do
        expect { result }.to change {
          Chat::UserChatThreadMembership.where(user: original_user).count
        }.by(1)
      end

      it "publishes user tracking state" do
        Chat::Publisher.expects(:publish_user_tracking_state!).with(user, channel, existing_message)
        result
      end

      it "doesn't update channel last_message attribute" do
        expect { result }.not_to change { channel.reload.last_message.id }
      end

      it "updates thread last_message attribute" do
        result
        expect(thread.reload.last_message).to eq message
      end

      it "doesn't update last_read_message attribute on the channel membership" do
        expect { result }.not_to change { membership.reload.last_read_message }
      end
    end

    context "when user is silenced" do
      before { UserSilencer.new(user).silence }

      it { is_expected.to fail_a_policy(:no_silenced_user) }
    end

    context "when user is not silenced" do
      context "when mandatory parameters are missing" do
        before { params[:chat_channel_id] = "" }

        it { is_expected.to fail_a_contract }
      end

      context "when mandatory parameters are present" do
        context "when channel model is not found" do
          before { params[:chat_channel_id] = -1 }

          it { is_expected.to fail_to_find_a_model(:channel) }
        end

        context "when channel model is found" do
          context "when user is not part of the channel" do
            before { channel.membership_for(user).destroy! }

            it { is_expected.to fail_to_find_a_model(:membership) }
          end

          context "when user is a bot" do
            fab!(:user) { Discourse.system_user }

            it { is_expected.to run_successfully }
          end

          context "when membership is enforced" do
            fab!(:user) { Fabricate(:user) }

            before do
              SiteSetting.chat_allowed_groups = [Group::AUTO_GROUPS[:everyone]]
              options[:enforce_membership] = true
            end

            it { is_expected.to run_successfully }
          end

          context "when user can join channel" do
            before { user.groups << Group.find(Group::AUTO_GROUPS[:trust_level_1]) }

            context "when user can't create a message in the channel" do
              before { channel.closed!(Discourse.system_user) }

              it { is_expected.to fail_a_policy(:allowed_to_create_message_in_channel) }
            end

            context "when user can create a message in the channel" do
              context "when user is a member of the channel" do
                fab!(:existing_message) { Fabricate(:chat_message, chat_channel: channel) }

                let(:membership) { channel.membership_for(user) }

                before do
                  membership.update!(last_read_message: existing_message)
                  DiscourseEvent.stubs(:trigger)
                end

                context "when message is a reply" do
                  before { params[:in_reply_to_id] = reply_to.id }

                  context "when reply is not part of the channel" do
                    fab!(:reply_to) { Fabricate(:chat_message) }

                    it { is_expected.to fail_a_policy(:ensure_reply_consistency) }
                  end

                  context "when reply is part of the channel" do
                    fab!(:reply_to) { Fabricate(:chat_message, chat_channel: channel) }

                    context "when reply is in a thread" do
                      fab!(:thread) do
                        Fabricate(:chat_thread, channel: channel, original_message: reply_to)
                      end

                      it_behaves_like "creating a new message"
                      it_behaves_like "a message in a thread"

                      it { is_expected.to run_successfully }

                      it "assigns the thread to the new message" do
                        expect(message).to have_attributes(
                          in_reply_to: an_object_having_attributes(thread: thread),
                          thread: thread,
                        )
                      end

                      it "does not publish the existing thread" do
                        Chat::Publisher.expects(:publish_thread_created!).never
                        result
                      end
                    end

                    context "when reply is not in a thread" do
                      let(:thread) { Chat::Thread.last }

                      it_behaves_like "creating a new message"
                      it_behaves_like "a message in a thread" do
                        let(:original_user) { reply_to.user }
                      end

                      it { is_expected.to run_successfully }

                      it "creates a new thread" do
                        expect { result }.to change { Chat::Thread.count }.by(1)
                        expect(message).to have_attributes(
                          in_reply_to: an_object_having_attributes(thread: thread),
                          thread: thread,
                        )
                      end

                      context "when threading is enabled in channel" do
                        it "publishes the new thread" do
                          Chat::Publisher.expects(:publish_thread_created!).with(
                            channel,
                            reply_to,
                            instance_of(Integer),
                            nil,
                          )
                          result
                        end
                      end

                      context "when threading is disabled in channel" do
                        before { channel.update!(threading_enabled: false) }

                        it "does not publish the new thread" do
                          Chat::Publisher.expects(:publish_thread_created!).never
                          result
                        end

                        context "when thread is forced" do
                          before { options[:force_thread] = true }

                          it "publishes the new thread" do
                            Chat::Publisher.expects(:publish_thread_created!).with(
                              channel,
                              reply_to,
                              instance_of(Integer),
                              nil,
                            )
                            result
                          end
                        end
                      end
                    end
                  end
                end

                context "when a thread is provided" do
                  before { params[:thread_id] = thread.id }

                  context "when thread is not part of the provided channel" do
                    let(:thread) { Fabricate(:chat_thread) }

                    it { is_expected.to fail_a_policy(:ensure_valid_thread_for_channel) }
                  end

                  context "when thread is part of the provided channel" do
                    let(:thread) { Fabricate(:chat_thread, channel: channel) }

                    context "when replying to an existing message" do
                      let(:reply_to) { Fabricate(:chat_message, chat_channel: channel) }

                      context "when reply thread does not match the provided thread" do
                        let!(:another_thread) do
                          Fabricate(:chat_thread, channel: channel, original_message: reply_to)
                        end

                        before { params[:in_reply_to_id] = reply_to.id }

                        it { is_expected.to fail_a_policy(:ensure_thread_matches_parent) }
                      end

                      context "when reply thread matches the provided thread" do
                        before { reply_to.update!(thread: thread) }

                        it_behaves_like "creating a new message"
                        it_behaves_like "a message in a thread"

                        it { is_expected.to run_successfully }

                        it "does not publish the thread" do
                          Chat::Publisher.expects(:publish_thread_created!).never
                          result
                        end
                      end
                    end

                    context "when not replying to an existing message" do
                      it_behaves_like "creating a new message"
                      it_behaves_like "a message in a thread"

                      it { is_expected.to run_successfully }

                      it "does not publish the thread" do
                        Chat::Publisher.expects(:publish_thread_created!).never
                        result
                      end
                    end
                  end
                end

                context "when nor thread nor reply is provided" do
                  context "when message is not valid" do
                    let(:content) { "a" * (SiteSetting.chat_maximum_message_length + 1) }

                    it { is_expected.to fail_with_an_invalid_model(:message_instance) }
                  end

                  context "when message is valid" do
                    it_behaves_like "creating a new message"

                    it { is_expected.to run_successfully }

                    it "updates membership last_read_message attribute" do
                      expect { result }.to change { membership.reload.last_read_message }
                    end

                    it "updates channel last_message attribute" do
                      result
                      expect(channel.reload.last_message).to eq message
                    end

                    it "publishes user tracking state" do
                      Chat::Publisher
                        .expects(:publish_user_tracking_state!)
                        .with(user, channel, existing_message)
                        .never
                      Chat::Publisher.expects(:publish_user_tracking_state!).with(
                        user,
                        channel,
                        instance_of(Chat::Message),
                      )
                      result
                    end
                  end
                end
              end
            end
          end
        end
      end
    end
  end
end
