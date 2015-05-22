require 'spec_helper'

describe StylesheetsController do

  it 'can survive cache miss' do
    DiscourseStylesheets.cache.clear
    DiscourseStylesheets.stylesheet_link_tag('desktop_rtl')

    StylesheetCache.destroy_all

    # digestless
    get :show, name: 'desktop_rtl'
    expect(response).to be_success

    # tmp folder destruction and cached
    `rm #{DiscourseStylesheets.cache_fullpath}/*`

    get :show, name: 'desktop_rtl'
    expect(response).to be_success

    # there is an edge case which is ... disk and db cache is nuked, very unlikely to happen

  end

end
