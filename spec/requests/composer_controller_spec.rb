require 'rails_helper'

RSpec.describe ComposerController do
  let(:user) { Fabricate(:user) }

  describe '#parse_html' do

    it "should not be able access without sign in" do
      expect {
        post "/composer/parse_html.json", params: {
          html: "<strong>hello</strong>"
        }
      }.to raise_error(Discourse::NotLoggedIn)
    end

    it "should convert html tags to markdown text" do
      sign_in(user)

      post "/composer/parse_html.json", params: {
        html: "<strong>hello</strong>"
      }

      expect(response.body).to eq("{\"markdown\":\"**hello**\"}")
    end
  end
end
