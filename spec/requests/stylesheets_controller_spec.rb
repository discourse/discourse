# frozen_string_literal: true

require 'rails_helper'

describe StylesheetsController do
  it 'can survive cache miss' do
    StylesheetCache.destroy_all
    builder = Stylesheet::Manager.new('desktop_rtl', nil)
    builder.compile

    digest = StylesheetCache.first.digest
    StylesheetCache.destroy_all

    get "/stylesheets/desktop_rtl_#{digest}.css"
    expect(response.status).to eq(200)

    cached = StylesheetCache.first
    expect(cached.target).to eq 'desktop_rtl'
    expect(cached.digest).to eq digest

    # tmp folder destruction and cached
    `rm #{Stylesheet::Manager.cache_fullpath}/*`

    get "/stylesheets/desktop_rtl_#{digest}.css"
    expect(response.status).to eq(200)

    # there is an edge case which is ... disk and db cache is nuked, very unlikely to happen
  end

  it 'can lookup theme specific css' do
    scheme = ColorScheme.create_from_base(name: "testing", colors: [])
    theme = Fabricate(:theme, color_scheme_id: scheme.id)

    builder = Stylesheet::Manager.new(:desktop, theme.id)
    builder.compile

    `rm #{Stylesheet::Manager.cache_fullpath}/*`

    get "/stylesheets/#{builder.stylesheet_filename.sub(".css", "")}.css"

    expect(response.status).to eq(200)

    get "/stylesheets/#{builder.stylesheet_filename_no_digest.sub(".css", "")}.css"

    expect(response.status).to eq(200)

    builder = Stylesheet::Manager.new(:desktop_theme, theme.id)
    builder.compile

    `rm #{Stylesheet::Manager.cache_fullpath}/*`

    get "/stylesheets/#{builder.stylesheet_filename.sub(".css", "")}.css"

    expect(response.status).to eq(200)

    get "/stylesheets/#{builder.stylesheet_filename_no_digest.sub(".css", "")}.css"

    expect(response.status).to eq(200)
  end
end
