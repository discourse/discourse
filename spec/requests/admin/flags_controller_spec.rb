require 'rails_helper'

RSpec.describe Admin::FlagsController do
  let(:admin) { Fabricate(:admin) }
  let(:post_1) { Fabricate(:post) }
  let(:user) { Fabricate(:user) }

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
    it 'should work' do
      SiteSetting.allow_user_locale = true
      SiteSetting.queue_jobs = false

      post_action = PostAction.act(user, post_1, PostActionType.types[:spam], message: 'bad')
      admin.update!(locale: 'ja')

      post "/admin/flags/agree/#{post_1.id}.json"

      expect(response.status).to eq(200)

      post_action.reload

      expect(post_action.agreed_by_id).to eq(admin.id)

      agree_post = Topic.joins(:topic_allowed_users).where('topic_allowed_users.user_id = ?', user.id).order(:id).last.posts.last
      expect(agree_post.raw).to eq(I18n.with_locale(:en) { I18n.t('flags_dispositions.agreed') })
    end
  end
end
