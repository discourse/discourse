require 'spec_helper'

describe RobotsTxtController do

  context '.index' do

    it "returns index when indexing is allowed" do
      SiteSetting.allow_index_in_robots_txt = true
      get :index
      expect(response).to render_template :index
    end

    it "returns noindex when indexing is disallowed" do
      SiteSetting.allow_index_in_robots_txt = false
      get :index
      expect(response).to render_template :no_index
    end

  end
end
