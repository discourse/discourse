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

    ['http://', 'HTTP://', 'https://', 'HTTPS://'].each do |prefix|
      it "strips #{prefix}" do
        described_class.create(valid_params.merge(url: url.gsub('http://', prefix))).url.should == url.gsub('http://', '')
      end
    end

    it "strips trailing slash" do
      described_class.create(valid_params.merge(url: 'silverbullet.in/')).url.should == 'silverbullet.in'
    end

    it "strips trailing slashes" do
      described_class.create(valid_params.merge(url: 'silverbullet.in/buy///')).url.should == 'silverbullet.in/buy'
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
