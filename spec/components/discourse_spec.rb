require 'spec_helper'
require 'discourse'

describe Discourse do

  before do
    RailsMultisite::ConnectionManagement.stubs(:current_hostname).returns('foo.com')
  end

  context 'current_hostname' do

    it 'returns the hostname from the current db connection' do
      Discourse.current_hostname.should == 'foo.com'
    end

  end

  context 'base_url' do

    context 'when ssl is off' do
      before do
        SiteSetting.expects(:use_ssl?).returns(false)
      end

      it 'has a non-ssl base url' do
        Discourse.base_url.should == "http://foo.com"
      end
    end

    context 'when ssl is on' do
      before do
        SiteSetting.expects(:use_ssl?).returns(true)
      end

      it 'has a non-ssl base url' do
        Discourse.base_url.should == "https://foo.com"
      end
    end

    context 'with a non standard port specified' do
      before do
        SiteSetting.stubs(:port).returns(3000)
      end

      it "returns the non standart port in the base url" do
        Discourse.base_url.should == "http://foo.com:3000"
      end

    end


  end


end

