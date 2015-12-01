require 'rails_helper'

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
    expect(items[0].has_filter?).to be_truthy
    expect(items[2].filter).to eq('not')
    expect(items[2].has_filter?).to be_truthy
  end

  it 'does not have a filter' do
    expect(items[1].filter).to be_nil
    expect(items[1].has_filter?).to be_falsey
    expect(items[3].filter).to be_nil
    expect(items[3].has_filter?).to be_falsey
  end

  it "has a specific category" do
    expect(items.first.has_specific_category?).to be_falsey
    expect(items.last.has_specific_category?).to be_truthy
  end

  it "does not have a specific category" do
    expect(items.first.specific_category).to be_nil
    expect(items.last.specific_category).to eq('xyz')
  end

end
