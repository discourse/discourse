# frozen_string_literal: true

require 'rails_helper'

describe StylesheetsController do
  it 'can survive cache miss' do
    StylesheetCache.destroy_all
    manager = Stylesheet::Manager.new(theme_id: nil)
    builder = Stylesheet::Manager::Builder.new(target: 'desktop_rtl', manager: manager, theme: nil)
    builder.compile

    digest = StylesheetCache.first.digest
    StylesheetCache.destroy_all

    get "/stylesheets/desktop_rtl_#{digest}.css"
    expect(response.status).to eq(200)

    cached = StylesheetCache.first
    expect(cached.target).to eq 'desktop_rtl'
    expect(cached.digest).to eq digest

    # tmp folder destruction and cached
    `rm -rf #{Stylesheet::Manager.cache_fullpath}`

    get "/stylesheets/desktop_rtl_#{digest}.css"
    expect(response.status).to eq(200)

    # there is an edge case which is ... disk and db cache is nuked, very unlikely to happen
  end

  it 'can lookup theme specific css' do
    scheme = ColorScheme.create_from_base(name: "testing", colors: [])
    theme = Fabricate(:theme, color_scheme_id: scheme.id)

    manager = Stylesheet::Manager.new(theme_id: theme.id)

    builder = Stylesheet::Manager::Builder.new(target: :desktop, theme: theme, manager: manager)
    builder.compile

    `rm -rf #{Stylesheet::Manager.cache_fullpath}`

    get "/stylesheets/#{builder.stylesheet_filename.sub(".css", "")}.css"

    expect(response.status).to eq(200)

    get "/stylesheets/#{builder.stylesheet_filename_no_digest.sub(".css", "")}.css"

    expect(response.status).to eq(200)

    builder = Stylesheet::Manager::Builder.new(target: :desktop_theme, theme: theme, manager: manager)
    builder.compile

    `rm -rf #{Stylesheet::Manager.cache_fullpath}`

    get "/stylesheets/#{builder.stylesheet_filename.sub(".css", "")}.css"

    expect(response.status).to eq(200)

    get "/stylesheets/#{builder.stylesheet_filename_no_digest.sub(".css", "")}.css"

    expect(response.status).to eq(200)
  end

  context "#color_scheme" do
    it 'works as expected' do
      scheme = ColorScheme.last
      get "/color-scheme-stylesheet/#{scheme.id}.json"

      expect(response.status).to eq(200)
      json = JSON.parse(response.body)
      expect(json["color_scheme_id"]).to eq(scheme.id)
    end

    it 'works with a theme parameter' do
      scheme = ColorScheme.last
      theme = Theme.last
      get "/color-scheme-stylesheet/#{scheme.id}/#{theme.id}.json"

      expect(response.status).to eq(200)
      json = JSON.parse(response.body)
      expect(json["color_scheme_id"]).to eq(scheme.id)
    end

  end
end
