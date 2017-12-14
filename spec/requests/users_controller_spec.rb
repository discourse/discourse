require 'rails_helper'

RSpec.describe UsersController do
  let(:user) { Fabricate(:user) }

  def honeypot_magic(params)
    get '/u/hp.json'
    json = JSON.parse(response.body)
    params[:password_confirmation] = json["value"]
    params[:challenge] = json["challenge"].reverse
    params
  end

  describe '#create' do

    context "when taking over a staged account" do
      let!(:staged) { Fabricate(:staged, email: "staged@account.com", active: true) }

      it "succeeds" do
        post '/u.json', params: honeypot_magic(
          email: staged.email,
          username: "zogstrip",
          password: "P4ssw0rd$$"
        )

        expect(response.status).to eq(200)
        result = ::JSON.parse(response.body)
        expect(result["success"]).to eq(true)

        created_user = User.find_by_email(staged.email)
        expect(created_user.staged).to eq(false)
        expect(created_user.active).to eq(false)
        expect(created_user.registration_ip_address).to be_present
        expect(!!created_user.custom_fields["from_staged"]).to eq(true)

        # do not allow emails changes please

        put "/u/update-activation-email.json", params: { email: 'bob@bob.com' }

        created_user.reload
        expect(created_user.email).to eq("staged@account.com")
        expect(response.status).not_to eq(200)
      end
    end

  end

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

  describe "#badges" do
    it "renders fine by default" do
      get "/u/#{user.username}/badges"
      expect(response).to be_success
    end

    it "fails if badges are disabled" do
      SiteSetting.enable_badges = false
      get "/u/#{user.username}/badges"
      expect(response.status).to eq(404)
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
      let!(:mentionable_group) do
        Fabricate(:group,
          mentionable_level: 99,
          messageable_level: 0,
          visibility_level: 0
        )
      end

      let!(:mentionable_group_2) do
        Fabricate(:group,
          mentionable_level: 99,
          messageable_level: 0,
          visibility_level: 1
        )
      end

      let!(:messageable_group) do
        Fabricate(:group,
          mentionable_level: 0,
          messageable_level: 99
        )
      end

      describe 'when signed in' do
        before do
          sign_in(user)
        end

        it "only returns visible groups" do
          get "/u/search/users.json", params: { include_groups: "true" }

          expect(response).to be_success

          groups = JSON.parse(response.body)["groups"]

          expect(groups.map { |group| group['name'] })
            .to_not include(mentionable_group_2.name)
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

          groups = JSON.parse(response.body)["groups"]

          expect(groups.map { |group| group['name'] })
            .to contain_exactly(mentionable_group.name, mentionable_group_2.name)
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
