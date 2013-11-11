require 'spec_helper'

describe EducationController do

  it "requires you to be logged in" do
    lambda { xhr :get, :show, id: 'topic' }.should raise_error(Discourse::NotLoggedIn)
  end

  context 'when logged in' do

    let!(:user) { log_in(:user) }

    it "returns 404 from a missing id" do
      xhr :get, :show, id: 'made-up'
      response.response_code.should == 404
    end

    it 'raises an error with a weird id' do
      xhr :get, :show, id: '../some-path'
      response.should_not be_success
    end

    context 'with a valid id' do

      let(:markdown_content) { "Education *markdown* content" }
      let(:html_content) {"HTML Content"}

      before do
        SiteContent.expects(:content_for).with(:education_new_topic, anything).returns(markdown_content)
        PrettyText.expects(:cook).with(markdown_content).returns(html_content)
        xhr :get, :show, id: 'new-topic'
      end

      it "succeeds" do
        response.should be_success
      end

      it "converts markdown into HTML" do
        response.body.should == html_content
      end

    end

  end

end
