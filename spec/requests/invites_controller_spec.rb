require 'rails_helper'

describe InvitesController do

  context 'show' do
    let(:invite) { Fabricate(:invite) }
    let(:user) { Fabricate(:coding_horror) }

    it "returns error if invite not found" do
      get "/invites/nopeNOPEnope"

      expect(response).to be_success

      body = response.body
      expect(body).to_not have_tag(:script, with: { src: '/assets/application.js' })
      expect(CGI.unescapeHTML(body)).to include(I18n.t('invite.not_found_template', site_name: SiteSetting.title, base_url: Discourse.base_url))
    end

    it "renders the accept invite page if invite exists" do
      get "/invites/#{invite.invite_key}"

      expect(response).to be_success

      body = response.body
      expect(body).to have_tag(:script, with: { src: '/assets/application.js' })
      expect(CGI.unescapeHTML(body)).to_not include(I18n.t('invite.not_found_template', site_name: SiteSetting.title, base_url: Discourse.base_url))
    end

    it "returns error if invite has already been redeemed" do
      invite.update_attributes!(redeemed_at: 1.day.ago)
      get "/invites/#{invite.invite_key}"

      expect(response).to be_success

      body = response.body
      expect(body).to_not have_tag(:script, with: { src: '/assets/application.js' })
      expect(CGI.unescapeHTML(body)).to include(I18n.t('invite.not_found_template', site_name: SiteSetting.title, base_url: Discourse.base_url))
    end
  end
end
