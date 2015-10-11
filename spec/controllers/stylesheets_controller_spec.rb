require 'rails_helper'

describe StylesheetsController do

  it 'can survive cache miss' do

    StylesheetCache.destroy_all
    builder = DiscourseStylesheets.new('desktop_rtl')
    builder.compile
    builder.ensure_digestless_file

    digest = StylesheetCache.first.digest
    StylesheetCache.destroy_all

    # digestless
    get :show, name: 'desktop_rtl'
    expect(response).to be_success

    StylesheetCache.destroy_all

    get :show, name: "desktop_rtl_#{digest}"
    expect(response).to be_success

    cached = StylesheetCache.first
    expect(cached.target).to eq 'desktop_rtl'
    expect(cached.digest).to eq digest

    # tmp folder destruction and cached
    `rm #{DiscourseStylesheets.cache_fullpath}/*`

    get :show, name: 'desktop_rtl'
    expect(response).to be_success

    get :show, name: "desktop_rtl_#{digest}"
    expect(response).to be_success

    # there is an edge case which is ... disk and db cache is nuked, very unlikely to happen

  end

end
