# frozen_string_literal: true

describe Chat::Api::CurrentUserThreadsController do
  fab!(:current_user, :user)

  before do
    SiteSetting.chat_enabled = true
    SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:everyone]
    sign_in(current_user)
  end

  describe "#index" do
    describe "success" do
      let!(:thread) do
        Fabricate(
          :chat_thread,
          original_message_user: current_user,
          with_replies: 2,
          use_service: true,
        )
      end

      it "works" do
        get "/chat/api/me/threads"

        expect(response).to have_http_status :ok
        expect(response.parsed_body[:threads]).not_to be_empty
      end

      context "when the user has lost access to a private channel" do
        fab!(:authorized_user, :user)
        fab!(:private_group, :group)
        fab!(:private_channel) do
          Fabricate(:private_category_channel, group: private_group, threading_enabled: true)
        end
        fab!(:private_original_message) do
          Fabricate(
            :chat_message,
            chat_channel: private_channel,
            message: "Former member private thread content",
          )
        end
        fab!(:private_thread) do
          Fabricate(
            :chat_thread,
            channel: private_channel,
            original_message: private_original_message,
            with_replies: 1,
          )
        end
        let(:private_message_after_revocation) do
          Fabricate(
            :chat_message,
            chat_channel: private_channel,
            message: "Private thread content created after revocation",
            thread: private_thread,
          ).tap { |message| private_thread.update!(last_message: message) }
        end

        before do
          private_group.add(current_user)
          private_group.add(authorized_user)
          private_channel.add(current_user)
          private_channel.add(authorized_user)
          private_thread.add(current_user)
          private_thread.add(authorized_user)
          GroupUser.where(group: private_group, user: current_user).destroy_all
          private_message_after_revocation
        end

        it "excludes post-revocation private content while retaining it for authorized members" do
          get "/chat/api/me/threads"

          expect(response).to have_http_status :ok
          expect(response.body).not_to include(private_original_message.message)
          expect(response.body).not_to include(private_message_after_revocation.message)
          expect(response.parsed_body["threads"].map { |thread| thread["id"] }).to contain_exactly(
            thread.id,
          )

          sign_in(authorized_user)
          get "/chat/api/me/threads"

          expect(response).to have_http_status :ok
          expect(response.body).to include(private_original_message.message)
          expect(response.body).to include(private_message_after_revocation.message)
          expect(response.parsed_body["threads"].map { |thread| thread["id"] }).to contain_exactly(
            private_thread.id,
          )
        end
      end
    end

    context "when threads are not found" do
      it "returns a 200 with empty threads" do
        get "/chat/api/me/threads"

        expect(response.status).to eq(200)
        expect(response.parsed_body["threads"]).to eq([])
      end
    end
  end
end
