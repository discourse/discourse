require 'rails_helper'

RSpec.describe RobotsTxtController do
  describe '#index' do
    it "returns index when indexing is allowed" do
      SiteSetting.allow_index_in_robots_txt = true
      get '/robots.txt'

      expect(response.body).to include("Disallow: /u/")
    end

    it "returns noindex when indexing is disallowed" do
      SiteSetting.allow_index_in_robots_txt = false
      get '/robots.txt'

      expect(response.body).to_not include("Disallow: /u/")
    end
  end
end
