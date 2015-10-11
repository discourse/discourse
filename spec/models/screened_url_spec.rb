require 'rails_helper'

describe ScreenedUrl do

  let(:url)    { 'http://shopppping.com/bad/drugz' }
  let(:domain) { 'shopppping.com' }

  let(:valid_params) { {url: url, domain: domain} }

  describe "new record" do
    it "sets a default action_type" do
      expect(described_class.create(valid_params).action_type).to eq(described_class.actions[:do_nothing])
    end

    it "last_match_at is null" do
      expect(described_class.create(valid_params).last_match_at).to eq(nil)
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
        expect(subject.url).to eq(url.gsub('http://', ''))
      end
    end

    it "strips trailing slash" do
      @params = valid_params.merge(url: 'silverbullet.in/')
      expect(subject.url).to eq('silverbullet.in')
    end

    it "strips trailing slashes" do
      @params = valid_params.merge(url: 'silverbullet.in/buy///')
      expect(subject.url).to eq('silverbullet.in/buy')
    end

    it "downcases domains" do
      record1 = described_class.new(valid_params.merge(domain: 'DuB30.com', url: 'DuB30.com/Gems/Gems-of-Power'))
      record1.normalize
      expect(record1.domain).to eq('dub30.com')
      expect(record1.url).to eq('dub30.com/Gems/Gems-of-Power')
      expect(record1).to be_valid

      record2 = described_class.new(valid_params.merge(domain: 'DuB30.com', url: 'DuB30.com'))
      record2.normalize
      expect(record2.domain).to eq('dub30.com')
      expect(record2.url).to eq('dub30.com')
      expect(record2).to be_valid
    end

    it "strips www. from domains" do
      record1 = described_class.new(valid_params.merge(domain: 'www.DuB30.com', url: 'www.DuB30.com/Gems/Gems-of-Power'))
      record1.normalize
      expect(record1.domain).to eq('dub30.com')

      record2 = described_class.new(valid_params.merge(domain: 'WWW.DuB30.cOM', url: 'WWW.DuB30.com/Gems/Gems-of-Power'))
      record2.normalize
      expect(record2.domain).to eq('dub30.com')

      record3 = described_class.new(valid_params.merge(domain: 'www.trolls.spammers.com', url: 'WWW.DuB30.com/Gems/Gems-of-Power'))
      record3.normalize
      expect(record3.domain).to eq('trolls.spammers.com')
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
      expect(described_class.find_match('http://spamspot.com/buy/it')).to eq(nil)
    end

    it 'returns the record when there is an exact match' do
      match = described_class.create(valid_params)
      expect(described_class.find_match(valid_params[:url])).to eq(match)
    end

    it 'ignores case of the domain' do
      match = described_class.create(valid_params.merge(url: 'spamexchange.com/Good/Things'))
      expect(described_class.find_match("http://SPAMExchange.com/Good/Things")).to eq(match)
    end
  end

  describe '#watch' do
    context 'url is not being blocked' do
      it 'creates a new record with default action of :do_nothing' do
        record = described_class.watch(url, domain)
        expect(record).not_to be_new_record
        expect(record.action_type).to eq(described_class.actions[:do_nothing])
      end

      it 'lets action_type be overriden' do
        record = described_class.watch(url, domain, action_type: described_class.actions[:block])
        expect(record).not_to be_new_record
        expect(record.action_type).to eq(described_class.actions[:block])
      end
    end

    context 'url is already being blocked' do
      let!(:existing) { Fabricate(:screened_url, url: url, domain: domain) }

      it "doesn't create a new record" do
        expect { described_class.watch(url, domain) }.to_not change { described_class.count }
      end

      it "returns the existing record" do
        expect(described_class.watch(url, domain)).to eq(existing)
      end
    end
  end
end
