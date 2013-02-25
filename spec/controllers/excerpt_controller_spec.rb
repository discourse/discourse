require 'spec_helper'

describe ExcerptController do

  describe 'show' do
    it 'raises an error without the url param' do
      lambda { xhr :get, :show }.should raise_error(Discourse::InvalidParameters)
    end

    it 'returns 404 with a non-existant url' do
      xhr :get, :show, url: 'http://madeup.com/url'
      response.status.should == 404
    end

    it 'returns 404 from an invalid url' do
      xhr :get, :show, url: 'asdfasdf'
      response.status.should == 404
    end

    describe 'user excerpt' do

      before do
        @user = Fabricate(:user)
        @url = "http://test.host/users/#{@user.username}"
        xhr :get, :show, url: @url
      end

      it 'returns a valid status' do
        response.should be_success
      end

      it 'returns an excerpt type for the forum topic' do
        parsed = JSON.parse(response.body)
        parsed['type'].should == 'User'
      end

    end

    describe 'forum topic excerpt' do

      before do
        @post = Fabricate(:post)
        @url = "http://test.host#{@post.topic.relative_url}"
        xhr :get, :show, url: @url
      end

      it 'returns a valid status' do
        response.should be_success
      end

      it 'returns an excerpt type for the forum topic' do
        parsed = JSON.parse(response.body)
        parsed['type'].should == 'Post'
      end

    end

    describe 'post excerpt' do

      before do
        @post = Fabricate(:post)
        @url = "http://test.host#{@post.topic.relative_url}/1"
        xhr :get, :show, url: @url
      end

      it 'returns a valid status' do
        response.should be_success
      end

      it 'returns an excerpt type for the forum topic' do
        parsed = JSON.parse(response.body)
        parsed['type'].should == 'Post'
      end

    end


  end



end
