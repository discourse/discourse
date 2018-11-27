require 'rails_helper'

RSpec.describe Admin::FlagsController do
  let(:user) { Fabricate(:user) }
  let(:admin) { Fabricate(:admin) }
  let(:post_1) { Fabricate(:post) }
  let(:category) { Fabricate(:category) }
  let(:first_post) { Fabricate(:post, post_number: 1) }

  before do
    sign_in(admin)
  end

  context '#index' do
    it 'should return the right response when nothing is flagged' do
      get '/admin/flags.json'

      expect(response.status).to eq(200)

      data = ::JSON.parse(response.body)
      expect(data["users"]).to eq([])
      expect(data["posts"]).to eq([])
    end

    it 'should return the right response' do
      PostAction.act(user, post_1, PostActionType.types[:spam])

      get '/admin/flags.json'

      expect(response.status).to eq(200)

      data = ::JSON.parse(response.body)
      expect(data["users"].length).to eq(2)
      expect(data["posts"].length).to eq(1)
    end
  end

  context '#agree' do
    it 'should raise a reasonable error if a flag was deferred and then someone else agreed' do
      SiteSetting.queue_jobs = false

      _post_action = PostAction.act(user, post_1, PostActionType.types[:spam], message: 'bad')

      post "/admin/flags/defer/#{post_1.id}.json"
      expect(response.status).to eq(200)

      post "/admin/flags/agree/#{post_1.id}.json", params: { action_on_post: 'keep' }
      # 409 means conflict which is what is happening here
      expect(response.status).to eq(409)
      error = JSON.parse(response.body)["errors"].first
      expect(error).to eq(I18n.t("flags.errors.already_handled"))
    end

    it 'should be able to agree and keep content' do
      SiteSetting.queue_jobs = false

      post_action = PostAction.act(user, post_1, PostActionType.types[:spam], message: 'bad')

      post "/admin/flags/agree/#{post_1.id}.json", params: { action_on_post: 'keep' }
      expect(response.status).to eq(200)

      post_action.reload
      expect(post_action.agreed_by_id).to eq(admin.id)
      expect(user.user_stat.reload.flags_agreed).to eq(1)

      post_1.reload
      expect(post_1.deleted_at).to eq(nil)
    end

    it 'should be able to hide spam' do
      SiteSetting.allow_user_locale = true
      SiteSetting.queue_jobs = false

      post_action = PostAction.act(user, post_1, PostActionType.types[:spam], message: 'bad')
      admin.update!(locale: 'ja')

      post "/admin/flags/agree/#{post_1.id}.json", params: { action_on_post: 'delete' }
      expect(response.status).to eq(200)

      post_action.reload

      expect(post_action.agreed_by_id).to eq(admin.id)
      expect(user.user_stat.reload.flags_agreed).to eq(1)

      agree_post = Topic.joins(:topic_allowed_users).where('topic_allowed_users.user_id = ?', user.id).order(:id).last.posts.last
      expect(agree_post.raw).to eq(I18n.with_locale(:en) { I18n.t('flags_dispositions.agreed_and_deleted') })

      post_1.reload
      expect(post_1.deleted_at).to be_present
    end

    it 'should not delete category topic' do
      SiteSetting.queue_jobs = false
      category.update_column(:topic_id, first_post.topic_id)

      PostAction.act(user, first_post, PostActionType.types[:spam], message: 'bad')

      post "/admin/flags/agree/#{first_post.id}.json", params: { action_on_post: 'delete' }
      expect(response.status).to eq(403)

      first_post.reload
      expect(first_post.deleted_at).to eq(nil)
    end
  end
end
