require 'rails_helper'

describe GroupsController do
  let(:group) { Fabricate(:group) }

  describe 'show' do
    it "ensures the group can be seen" do
      Guardian.any_instance.expects(:can_see?).with(group).returns(false)
      get :show, params: { id: group.name }, format: :json
      expect(response).not_to be_success
    end

    it "responds with JSON" do
      Guardian.any_instance.expects(:can_see?).with(group).returns(true)
      get :show, params: { id: group.name }, format: :json
      expect(response).to be_success
      expect(::JSON.parse(response.body)['basic_group']['id']).to eq(group.id)
    end

    it "works even with an upper case group name" do
      Guardian.any_instance.expects(:can_see?).with(group).returns(true)
      get :show, params: { id: group.name.upcase }, format: :json
      expect(response).to be_success
      expect(::JSON.parse(response.body)['basic_group']['id']).to eq(group.id)
    end
  end

  describe "posts" do
    it "ensures the group can be seen" do
      Guardian.any_instance.expects(:can_see?).with(group).returns(false)
      get :posts, params: { group_id: group.name }, format: :json
      expect(response).not_to be_success
    end

    it "calls `posts_for` and responds with JSON" do
      Guardian.any_instance.expects(:can_see?).with(group).returns(true)
      Group.any_instance.expects(:posts_for).returns(Group.none)
      get :posts, params: { group_id: group.name }, format: :json
      expect(response).to be_success
    end
  end

  describe "members" do
    it "ensures the group can be seen" do
      Guardian.any_instance.expects(:can_see?).with(group).returns(false)
      get :members, params: { group_id: group.name }, format: :json
      expect(response).not_to be_success
    end

    it "calls `posts_for` and responds with JSON" do
      Guardian.any_instance.expects(:can_see?).with(group).returns(true)
      get :posts, params: { group_id: group.name }, format: :json
      expect(response).to be_success
    end

    it "ensures that membership can be paginated" do
      5.times { group.add(Fabricate(:user)) }
      usernames = group.users.map { |m| m.username }.sort

      get :members, params: { group_id: group.name, limit: 3 }, format: :json
      expect(response).to be_success
      members = JSON.parse(response.body)["members"]
      expect(members.map { |m| m['username'] }).to eq(usernames[0..2])

      get :members, params: { group_id: group.name, limit: 3, offset: 3 }, format: :json
      expect(response).to be_success
      members = JSON.parse(response.body)["members"]
      expect(members.map { |m| m['username'] }).to eq(usernames[3..4])
    end
  end

  describe '.posts_feed' do
    it 'renders RSS' do
      get :posts_feed, params: { group_id: group.name }, format: :rss
      expect(response).to be_success
      expect(response.content_type).to eq('application/rss+xml')
    end
  end

  describe '.mentions_feed' do
    it 'renders RSS' do
      get :mentions_feed, params: { group_id: group.name }, format: :rss
      expect(response).to be_success
      expect(response.content_type).to eq('application/rss+xml')
    end

    it 'fails when disabled' do
      SiteSetting.enable_mentions = false
      get :mentions_feed, params: { group_id: group.name }, format: :rss
      expect(response).not_to be_success
    end
  end

end
