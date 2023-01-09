# frozen_string_literal: true

module HighlightJs
  HIGHLIGHTJS_DIR ||= "#{Rails.root}/vendor/assets/javascripts/highlightjs/"
  BUNDLED_LANGS = %w[
    bash
    c
    cpp
    csharp
    css
    diff
    go
    graphql
    ini
    java
    javascript
    json
    kotlin
    less
    lua
    makefile
    xml
    markdown
    objectivec
    perl
    php
    php-template
    plaintext
    python
    python-repl
    r
    ruby
    rust
    scss
    shell
    sql
    swift
    typescript
    vbnet
    wasm
    yaml
  ]

  def self.languages
    langs = Dir.glob(HIGHLIGHTJS_DIR + "languages/*.js").map { |path| File.basename(path)[0..-8] }

    langs.sort
  end

  def self.bundle(langs)
    result = File.read(HIGHLIGHTJS_DIR + "highlight.min.js")
    (langs - BUNDLED_LANGS).each do |lang|
      begin
        result << "\n" << File.read(HIGHLIGHTJS_DIR + "languages/#{lang}.min.js")
      rescue Errno::ENOENT
        # no file, don't care
      end
    end

    result
  end

  def self.version(lang_string)
    (@lang_string_cache ||= {})[lang_string] ||= Digest::SHA1.hexdigest(
      bundle lang_string.split("|")
    )
  end

  def self.path
    "/highlight-js/#{Discourse.current_hostname}/#{version SiteSetting.highlighted_languages}.js"
  end
end
