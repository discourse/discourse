require 'spec_helper'

describe StaticController do

  context "with a static file that's present" do

    before do
      xhr :get, :show, :id => 'faq'
    end

    it 'renders the static file if present' do
      response.should be_success
    end

    it "renders the file" do
      response.should render_template('faq')
    end
  end

  context "with a missing file" do
    it "should respond 404" do
      xhr :get, :show, :id => 'does-not-exist'
      response.response_code.should == 404
    end
  end

end
