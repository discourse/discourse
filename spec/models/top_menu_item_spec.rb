require 'spec_helper'

describe TopMenuItem do
  before(:each) { SiteSetting.stubs(:top_menu).returns('one,-nope|two|three,-not|four,ignored|category/xyz') }
  let(:items) { SiteSetting.top_menu_items }

  it 'has name' do
    expect(items[0].name).to eq('one')
    expect(items[1].name).to eq('two')
    expect(items[2].name).to eq('three')
  end

  it 'has a filter' do
    expect(items[0].filter).to eq('nope')
    expect(items[0].has_filter?).to be_true
    expect(items[2].filter).to eq('not')
    expect(items[2].has_filter?).to be_true
  end

  it 'does not have a filter' do
    expect(items[1].filter).to be_nil
    expect(items[1].has_filter?).to be_false
    expect(items[3].filter).to be_nil
    expect(items[3].has_filter?).to be_false
  end

  it "has a specific category" do
    expect(items.first.has_specific_category?).to be_false
    expect(items.last.has_specific_category?).to be_true
  end

  it "does not have a specific category" do
    expect(items.first.specific_category).to be_nil
    expect(items.last.specific_category).to eq('xyz')
  end

  describe "matches_action?" do
    it "does not match index on other pages" do
      expect(TopMenuItem.new('xxxx').matches_action?("index")).to be_false
    end

    it "matches index on homepage" do
      expect(items[0].matches_action?("index")).to be_true
    end

    it "matches current action" do
      expect(items[1].matches_action?("two")).to be_true
    end

    it "does not match current action" do
      expect(items[1].matches_action?("one")).to be_false
    end
  end

  describe "query_should_exclude_category" do
    before(:each) do
      items[0].stubs(:matches_action?).returns(true)
      items[0].stubs(:has_filter?).returns(true)
    end

    it "excludes category" do
      expect(items[0].query_should_exclude_category?(nil, nil)).to be_true
    end

    it "does not exclude for json format" do
      expect(items[0].query_should_exclude_category?(nil, 'json')).to be_false
    end
  end
end