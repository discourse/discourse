require 'spec_helper'

describe RobotsTxtController do

  context '.index' do

    it "returns index when indexing is allowed" do
      SiteSetting.stubs(:allow_index_in_robots_txt).returns(true)
      get :index
      response.should render_template :index
    end

    it "returns noindex when indexing is disallowed" do
      SiteSetting.stubs(:allow_index_in_robots_txt).returns(false)
      get :index
      response.should render_template :no_index
    end

  end
end
