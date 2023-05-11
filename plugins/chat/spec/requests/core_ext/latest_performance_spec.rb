# frozen_string_literal: true

describe ListController do
  fab!(:current_user) { Fabricate(:user) }

  before do
    SiteSetting.chat_enabled = true
    Group.refresh_automatic_groups!
    sign_in(current_user)
  end

  describe "#latest" do
    it "does not do N+1 chat_channel_archive queries based on the number of public and DM channels" do
      user_1 = Fabricate(:user)
      Fabricate(:direct_message_channel, users: [current_user, user_1])
      public_channel_1 = Fabricate(:chat_channel)
      public_channel_2 = Fabricate(:chat_channel)

      Fabricate(
        :user_chat_channel_membership,
        user: current_user,
        chat_channel: public_channel_1,
        following: true,
      )

      # warm up
      get "/latest.html"
      expect(response.status).to eq(200)

      initial_sql_queries_count =
        track_sql_queries do
          get "/latest.html"
          expect(response.status).to eq(200)
          expect(response.body).to have_tag("div#data-preloaded") do |element|
            current_user_json =
              JSON.parse(
                JSON.parse(element.current_scope.attribute("data-preloaded").value)["currentUser"],
              )
            expect(current_user_json["chat_channels"]["direct_message_channels"].count).to eq(1)
            expect(current_user_json["chat_channels"]["public_channels"].count).to eq(1)
          end
        end.count

      Fabricate(
        :user_chat_channel_membership,
        user: current_user,
        chat_channel: public_channel_2,
        following: true,
      )
      user_2 = Fabricate(:user)
      Fabricate(:direct_message_channel, users: [current_user, user_2])

      new_sql_queries_count =
        track_sql_queries do
          get "/latest.html"
          expect(response.status).to eq(200)
          expect(response.body).to have_tag("div#data-preloaded") do |element|
            current_user_json =
              JSON.parse(
                JSON.parse(element.current_scope.attribute("data-preloaded").value)["currentUser"],
              )
            expect(current_user_json["chat_channels"]["direct_message_channels"].count).to eq(2)
            expect(current_user_json["chat_channels"]["public_channels"].count).to eq(2)
          end
        end.count

      expect(new_sql_queries_count).to be <= initial_sql_queries_count
    end
  end
end
