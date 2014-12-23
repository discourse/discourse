require 'spec_helper'

describe Admin::EmojisController do

  let(:custom_emoji) do
    Emoji.new("/path/to/hello").tap do |e|
      e.name = "hello"
      e.url = "/url/to/hello.png"
    end
  end

  it "is a subclass of AdminController" do
    (Admin::EmojisController < Admin::AdminController).should == true
  end

  context "when logged in" do
    let!(:user) { log_in(:admin) }

    context '.index' do
      it "returns a list of custom emojis" do
        Emoji.expects(:custom).returns([custom_emoji])
        xhr :get, :index
        response.should be_success
        json = ::JSON.parse(response.body)
        json[0]['name'].should == custom_emoji.name
        json[0]['url'].should == custom_emoji.url
      end
    end

    context '.create' do

      before { Emoji.expects(:all).returns([custom_emoji]) }

      context 'name already exist' do
        it "throws an error" do
          xhr :post, :create, { name: "hello", file: "" }
          response.should_not be_success
        end
      end

      context 'error while saving emoji' do
        it "throws an error" do
          Emoji.expects(:create_for).returns(nil)
          xhr :post, :create, { name: "garbage", file: "" }
          response.should_not be_success
        end
      end

      context 'it works' do
        let(:custom_emoji2) do
          Emoji.new("/path/to/hello2").tap do |e|
            e.name = "hello2"
            e.url = "/url/to/hello2.png"
          end
        end

        it "creates a custom emoji" do
          Emoji.expects(:create_for).returns(custom_emoji2)
          xhr :post, :create, { name: "hello2", file: ""}
          response.should be_success
          json = ::JSON.parse(response.body)
          json['name'].should == custom_emoji2.name
          json['url'].should == custom_emoji2.url
        end

      end
    end

    context '.destroy' do
      it "deletes the custom emoji" do
        custom_emoji.expects(:remove)
        Emoji.expects(:custom).returns([custom_emoji])
        xhr :delete, :destroy, id: "hello"
        response.should be_success
      end
    end
  end

end

