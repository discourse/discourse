require 'rails_helper'

RSpec.describe ApplicationController do
  describe '#redirect_to_login_if_required' do
    let(:admin) { Fabricate(:admin) }

    before do
      admin  # to skip welcome wizard at home page `/`
      SiteSetting.login_required = true
    end

    it "should carry-forward authComplete param to login page redirect" do
      get "/?authComplete=true"
      expect(response).to redirect_to('/login?authComplete=true')
    end
  end

  describe 'build_not_found_page' do
    describe 'topic not found' do
      it 'should return 404 and show Google search' do
        get "/t/nope-nope/99999999"
        expect(response.status).to eq(404)
        expect(response.body).to include(I18n.t('page_not_found.search_google'))
      end

      it 'should not include Google search if login_required is enabled' do
        SiteSetting.login_required = true
        sign_in(Fabricate(:user))
        get "/t/nope-nope/99999999"
        expect(response.status).to eq(404)
        expect(response.body).to_not include('google.com/search')
      end
    end
  end

  describe "#handle_theme" do
    let(:theme) { Theme.create!(user_id: -1, name: 'bob', user_selectable: true) }
    let(:theme2) { Theme.create!(user_id: -1, name: 'bobbob', user_selectable: true) }
    let(:user) { Fabricate(:user) }
    let(:admin) { Fabricate(:admin) }

    before do
      sign_in(user)
    end

    it "selects the theme the user has selected" do
      user.user_option.update_columns(theme_ids: [theme.id])

      get "/"
      expect(controller.theme_ids).to eq([theme.id])

      theme.update_attribute(:user_selectable, false)

      get "/"
      expect(controller.theme_ids).not_to eq([theme.id])
    end

    it "can be overridden with a cookie" do
      user.user_option.update_columns(theme_ids: [theme.id])

      cookies['theme_ids'] = "#{theme2.id}|#{user.user_option.theme_key_seq}"

      get "/"
      expect(controller.theme_ids).to eq([theme2.id])

      theme2.update!(user_selectable: false)
      theme.add_child_theme!(theme2)
      cookies['theme_ids'] = "#{theme.id},#{theme2.id}|#{user.user_option.theme_key_seq}"

      get "/"
      expect(controller.theme_ids).to eq([theme.id, theme2.id])
    end

    it "falls back to the default theme when the user has no cookies or preferences" do
      user.user_option.update_columns(theme_ids: [])
      cookies["theme_ids"] = nil
      theme2.set_default!

      get "/"
      expect(controller.theme_ids).to eq([theme2.id])
    end

    it "can be overridden with preview_theme_id param" do
      sign_in(admin)
      cookies['theme_ids'] = "#{theme.id},#{theme2.id}|#{admin.user_option.theme_key_seq}"

      get "/?preview_theme_id=#{theme2.id}"
      expect(controller.theme_ids).to eq([theme2.id])
    end

    it "cookie can fail back to user if out of sync" do
      user.user_option.update_columns(theme_ids: [theme.id])
      cookies['theme_ids'] = "#{theme2.id}|#{user.user_option.theme_key_seq - 1}"

      get "/"
      expect(controller.theme_ids).to eq([theme.id])
    end
  end
end
