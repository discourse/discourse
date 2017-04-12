require 'rails_helper'

describe StylesheetsController do

  it 'can survive cache miss' do

    StylesheetCache.destroy_all
    builder = Stylesheet::Manager.new('desktop_rtl', nil)
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
    `rm #{Stylesheet::Manager.cache_fullpath}/*`

    get :show, name: 'desktop_rtl'
    expect(response).to be_success

    get :show, name: "desktop_rtl_#{digest}"
    expect(response).to be_success

    # there is an edge case which is ... disk and db cache is nuked, very unlikely to happen

  end

  it 'can lookup theme specific css' do
    scheme = ColorScheme.create_from_base({name: "testing", colors: []})
    theme = Theme.create!(name: "test", color_scheme_id: scheme.id, user_id: -1)

    builder = Stylesheet::Manager.new(:desktop, theme.key)
    builder.compile

    `rm #{Stylesheet::Manager.cache_fullpath}/*`

    get :show, name: builder.stylesheet_filename.sub(".css", "")
    expect(response).to be_success

    get :show, name: builder.stylesheet_filename_no_digest.sub(".css", "")
    expect(response).to be_success

    builder = Stylesheet::Manager.new(:desktop_theme, theme.key)
    builder.compile

    `rm #{Stylesheet::Manager.cache_fullpath}/*`

    get :show, name: builder.stylesheet_filename.sub(".css", "")
    expect(response).to be_success

    get :show, name: builder.stylesheet_filename_no_digest.sub(".css", "")
    expect(response).to be_success
  end

end
