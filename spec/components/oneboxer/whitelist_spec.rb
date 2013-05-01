require 'spec_helper'
require 'oneboxer'
require 'oneboxer/whitelist'

describe Oneboxer::Whitelist do
  it "matches an arbitrary Discourse post link" do
    Oneboxer::Whitelist.entry_for_url('http://meta.discourse.org/t/scrolling-up-not-loading-in-firefox/3340/6?123').should_not be_nil
  end

  it "matches an arbitrary Discourse topic link" do
    Oneboxer::Whitelist.entry_for_url('http://meta.discourse.org/t/scrolling-up-not-loading-in-firefox/3340?123').should_not be_nil
  end

  it "Does not match on slight variation" do
    Oneboxer::Whitelist.entry_for_url('http://meta.discourse.org/t/scrolling-up-not-loading-in-firefox/3340a?123').should be_nil
  end

end
