require 'spec_helper'

describe ScreenedUrl do

  let(:url)    { 'http://shopppping.com/bad/drugz' }
  let(:domain) { 'shopppping.com' }

  let(:valid_params) { {url: url, domain: domain} }

  describe "new record" do
    it "sets a default action_type" do
      described_class.create(valid_params).action_type.should == described_class.actions[:do_nothing]
    end

    it "last_match_at is null" do
      described_class.create(valid_params).last_match_at.should be_nil
    end

    it "normalizes the url and domain" do
      record = described_class.new(valid_params)
      record.expects(:normalize).once
      record.valid?
    end
  end

  describe 'normalize' do
    let(:record) { described_class.new(@params) }
    subject { record.normalize; record }

    ['http://', 'HTTP://', 'https://', 'HTTPS://'].each do |prefix|
      it "strips #{prefix}" do
        @params = valid_params.merge(url: url.gsub('http://', prefix))
        subject.url.should == url.gsub('http://', '')
      end
    end

    it "strips trailing slash" do
      @params = valid_params.merge(url: 'silverbullet.in/')
      subject.url.should == 'silverbullet.in'
    end

    it "strips trailing slashes" do
      @params = valid_params.merge(url: 'silverbullet.in/buy///')
      subject.url.should == 'silverbullet.in/buy'
    end

    it "downcases domains" do
      record1 = described_class.new(valid_params.merge(domain: 'DuB30.com', url: 'DuB30.com/Gems/Gems-of-Power'))
      record1.normalize
      record1.domain.should == 'dub30.com'
      record1.url.should == 'dub30.com/Gems/Gems-of-Power'
      record1.should be_valid

      record2 = described_class.new(valid_params.merge(domain: 'DuB30.com', url: 'DuB30.com'))
      record2.normalize
      record2.domain.should == 'dub30.com'
      record2.url.should == 'dub30.com'
      record2.should be_valid
    end

    it "strips www. from domains" do
      record1 = described_class.new(valid_params.merge(domain: 'www.DuB30.com', url: 'www.DuB30.com/Gems/Gems-of-Power'))
      record1.normalize
      record1.domain.should == 'dub30.com'

      record2 = described_class.new(valid_params.merge(domain: 'WWW.DuB30.cOM', url: 'WWW.DuB30.com/Gems/Gems-of-Power'))
      record2.normalize
      record2.domain.should == 'dub30.com'

      record3 = described_class.new(valid_params.merge(domain: 'www.trolls.spammers.com', url: 'WWW.DuB30.com/Gems/Gems-of-Power'))
      record3.normalize
      record3.domain.should == 'trolls.spammers.com'
    end

    it "doesn't modify the url argument" do
      expect {
        described_class.new(valid_params).normalize
      }.to_not change { valid_params[:url] }
    end

    it "doesn't modify the domain argument" do
      params = valid_params.merge(domain: domain.upcase)
      expect {
        described_class.new(params).normalize
      }.to_not change { params[:domain] }
    end
  end

  describe 'find_match' do
    it 'returns nil when there is no match' do
      described_class.find_match('http://spamspot.com/buy/it').should be_nil
    end

    it 'returns the record when there is an exact match' do
      match = described_class.create(valid_params)
      described_class.find_match(valid_params[:url]).should == match
    end

    it 'ignores case of the domain' do
      match = described_class.create(valid_params.merge(url: 'spamexchange.com/Good/Things'))
      described_class.find_match("http://SPAMExchange.com/Good/Things").should == match
    end
  end

  describe '#watch' do
    context 'url is not being blocked' do
      it 'creates a new record with default action of :do_nothing' do
        record = described_class.watch(url, domain)
        record.should_not be_new_record
        record.action_type.should == described_class.actions[:do_nothing]
      end

      it 'lets action_type be overriden' do
        record = described_class.watch(url, domain, action_type: described_class.actions[:block])
        record.should_not be_new_record
        record.action_type.should == described_class.actions[:block]
      end
    end

    context 'url is already being blocked' do
      let!(:existing) { Fabricate(:screened_url, url: url, domain: domain) }

      it "doesn't create a new record" do
        expect { described_class.watch(url, domain) }.to_not change { described_class.count }
      end

      it "returns the existing record" do
        described_class.watch(url, domain).should == existing
      end
    end
  end
end
