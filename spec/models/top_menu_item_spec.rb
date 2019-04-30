# frozen_string_literal: true

require 'rails_helper'

describe TopMenuItem do
  before do
    SiteSetting.top_menu = 'categories|latest'
  end

  let(:items) { SiteSetting.top_menu_items }

  it 'has name' do
    expect(items[0].name).to eq('categories')
    expect(items[1].name).to eq('latest')
  end

end
