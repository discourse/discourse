require 'rails_helper'

RSpec.describe UsersController do
  let(:user) { Fabricate(:user) }

  describe '#show' do

    it "should be able to view a user" do
      get "/u/#{user.username}"

      expect(response).to be_success
      expect(response.body).to include(user.username)
    end

    describe 'when username contains a period' do
      before do
        user.update!(username: 'test.test')
      end

      it "should be able to view a user" do
        get "/u/#{user.username}"

        expect(response).to be_success
        expect(response.body).to include(user.username)
      end
    end
  end

  describe "updating a user" do
    before do
      sign_in(user)
    end

    it "should be able to update a user" do
      put "/u/#{user.username}.json", params: { name: 'test.test' }

      expect(response).to be_success
      expect(user.reload.name).to eq('test.test')
    end

    describe 'when username contains a period' do
      before do
        user.update!(username: 'test.test')
      end

      it "should be able to update a user" do
        put "/u/#{user.username}.json", params: { name: 'testing123' }

        expect(response).to be_success
        expect(user.reload.name).to eq('testing123')
      end
    end
  end

  describe "#account_created" do
    it "returns a message when no session is present" do
      get "/u/account-created"

      expect(response).to be_success

      body = response.body

      expect(body).to match(I18n.t('activation.missing_session'))
    end

    it "redirects when the user is logged in" do
      sign_in(Fabricate(:user))
      get "/u/account-created"

      expect(response).to redirect_to("/")
    end

    context "when the user account is created" do
      include ApplicationHelper

      it "returns the message when set in the session" do
        user = create_user
        get "/u/account-created"

        expect(response).to be_success

        expect(response.body).to include(
          "{\"message\":\"#{I18n.t("login.activate_email", email: user.email).gsub!("</", "<\\/")}\",\"show_controls\":true,\"username\":\"#{user.username}\",\"email\":\"#{user.email}\"}"
        )
      end
    end
  end

  describe "search_users" do
    let(:topic) { Fabricate :topic }
    let(:user)  { Fabricate :user, username: "joecabot", name: "Lawrence Tierney" }
    let(:post1) { Fabricate(:post, user: user, topic: topic) }

    before do
      SearchIndexer.enable
      post1
    end

    it "searches when provided the term only" do
      get "/u/search/users.json", params: { term: user.name.split(" ").last }
      expect(response).to be_success
      json = JSON.parse(response.body)
      expect(json["users"].map { |u| u["username"] }).to include(user.username)
    end

    it "searches when provided the topic only" do
      get "/u/search/users.json", params: { topic_id: topic.id }
      expect(response).to be_success
      json = JSON.parse(response.body)
      expect(json["users"].map { |u| u["username"] }).to include(user.username)
    end

    it "searches when provided the term and topic" do
      get "/u/search/users.json", params: {
        term: user.name.split(" ").last, topic_id: topic.id
      }

      expect(response).to be_success
      json = JSON.parse(response.body)
      expect(json["users"].map { |u| u["username"] }).to include(user.username)
    end

    it "searches only for users who have access to private topic" do
      privileged_user = Fabricate(:user, trust_level: 4, username: "joecabit", name: "Lawrence Tierney")
      privileged_group = Fabricate(:group)
      privileged_group.add(privileged_user)
      privileged_group.save

      category = Fabricate(:category)
      category.set_permissions(privileged_group => :readonly)
      category.save

      private_topic = Fabricate(:topic, category: category)

      get "/u/search/users.json", params: {
        term: user.name.split(" ").last, topic_id: private_topic.id, topic_allowed_users: "true"
      }

      expect(response).to be_success
      json = JSON.parse(response.body)
      expect(json["users"].map { |u| u["username"] }).to_not include(user.username)
      expect(json["users"].map { |u| u["username"] }).to include(privileged_user.username)
    end

    context "when `enable_names` is true" do
      before do
        SiteSetting.enable_names = true
      end

      it "returns names" do
        get "/u/search/users.json", params: { term: user.name }
        json = JSON.parse(response.body)
        expect(json["users"].map { |u| u["name"] }).to include(user.name)
      end
    end

    context "when `enable_names` is false" do
      before do
        SiteSetting.enable_names = false
      end

      it "returns names" do
        get "/u/search/users.json", params: { term: user.name }
        json = JSON.parse(response.body)
        expect(json["users"].map { |u| u["name"] }).not_to include(user.name)
      end
    end

    context 'groups' do
      let!(:mentionable_group) { Fabricate(:group, mentionable_level: 99, messageable_level: 0) }
      let!(:messageable_group) { Fabricate(:group, mentionable_level: 0, messageable_level: 99) }

      describe 'when signed in' do
        before do
          sign_in(user)
        end

        it "doesn't search for groups" do
          get "/u/search/users.json", params: {
            include_mentionable_groups: 'false',
            include_messageable_groups: 'false'
          }

          expect(response).to be_success
          expect(JSON.parse(response.body)).not_to have_key(:groups)
        end

        it "searches for messageable groups" do
          get "/u/search/users.json", params: {
            include_mentionable_groups: 'false',
            include_messageable_groups: 'true'
          }

          expect(response).to be_success
          expect(JSON.parse(response.body)["groups"].first['name']).to eq(messageable_group.name)
        end

        it 'searches for mentionable groups' do
          get "/u/search/users.json", params: {
            include_messageable_groups: 'false',
            include_mentionable_groups: 'true'
          }

          expect(response).to be_success
          expect(JSON.parse(response.body)["groups"].first['name']).to eq(mentionable_group.name)
        end
      end

      describe 'when not signed in' do
        it 'should not include mentionable/messageable groups' do
          get "/u/search/users.json", params: {
            include_mentionable_groups: 'false',
            include_messageable_groups: 'false'
          }

          expect(response).to be_success
          expect(JSON.parse(response.body)).not_to have_key(:groups)

          get "/u/search/users.json", params: {
            include_mentionable_groups: 'false',
            include_messageable_groups: 'true'
          }

          expect(response).to be_success
          expect(JSON.parse(response.body)).not_to have_key(:groups)

          get "/u/search/users.json", params: {
            include_messageable_groups: 'false',
            include_mentionable_groups: 'true'
          }

          expect(response).to be_success
          expect(JSON.parse(response.body)).not_to have_key(:groups)
        end
      end
    end
  end
end
