# frozen_string_literal: true

# Helper to render a no-op inline script tag to work around a safari bug
# which causes `defer` scripts to be run before stylesheets are loaded.
# https://bugs.webkit.org/show_bug.cgi?id=209261
module DeferScriptHelper
  def self.safari_workaround_script
    <<~HTML.html_safe
      <script>#{raw_js}</script>
    HTML
  end

  def self.fingerprint
    @fingerprint ||= calculate_fingerprint
  end

  private

  def self.raw_js
    "/* Workaround for https://bugs.webkit.org/show_bug.cgi?id=209261 */"
  end

  def self.calculate_fingerprint
    "sha256-#{Digest::SHA256.base64digest(raw_js)}"
  end
end
