require 'rails_helper'

RSpec.describe "Managing flags as an admin" do
  let(:admin) { Fabricate(:admin) }
  let(:post) { Fabricate(:post) }
  let(:user) { Fabricate(:user) }

  before do
    sign_in(admin)
  end

  context 'viewing flags' do
    it 'should return the right response when nothing is flagged' do
      get '/admin/flags.json'

      expect(response).to be_success

      data = ::JSON.parse(response.body)
      expect(data["users"]).to eq([])
      expect(data["posts"]).to eq([])
    end

    it 'should return the right response' do
      PostAction.act(user, post, PostActionType.types[:spam])

      get '/admin/flags.json'

      expect(response).to be_success

      data = ::JSON.parse(response.body)
      data["users"].length == 2
      data["posts"].length == 1
    end
  end

  context 'agreeing with a flag' do
    it 'should work' do
      SiteSetting.allow_user_locale = true
      post_action = PostAction.act(user, post, PostActionType.types[:spam], message: 'bad')
      admin.update!(locale: 'ja')

      xhr :post, "/admin/flags/agree/#{post.id}"

      expect(response).to be_success

      post_action.reload

      expect(post_action.agreed_by_id).to eq(admin.id)

      post = Post.offset(1).last

      expect(post.raw).to eq(I18n.with_locale(:en) { I18n.t('flags_dispositions.agreed') })
    end
  end
end
