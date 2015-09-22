require 'spec_helper'

describe EmbeddableHost do

  it "trims http" do
    eh = EmbeddableHost.new(host: 'http://example.com')
    expect(eh).to be_valid
    expect(eh.host).to eq('example.com')
  end

  it "trims https" do
    eh = EmbeddableHost.new(host: 'https://example.com')
    expect(eh).to be_valid
    expect(eh.host).to eq('example.com')
  end

  it "trims paths" do
    eh = EmbeddableHost.new(host: 'https://example.com/1234/45')
    expect(eh).to be_valid
    expect(eh.host).to eq('example.com')
  end

  describe "allows_embeddable_host" do
    let!(:host) { Fabricate(:embeddable_host) }

    it 'works as expected' do
      expect(EmbeddableHost.host_allowed?('http://eviltrout.com')).to eq(true)
      expect(EmbeddableHost.host_allowed?('https://eviltrout.com')).to eq(true)
      expect(EmbeddableHost.host_allowed?('https://not-eviltrout.com')).to eq(false)
    end

    it 'works with multiple hosts' do
      Fabricate(:embeddable_host, host: 'discourse.org')
      expect(EmbeddableHost.host_allowed?('http://eviltrout.com')).to eq(true)
      expect(EmbeddableHost.host_allowed?('http://discourse.org')).to eq(true)
    end

  end

end
