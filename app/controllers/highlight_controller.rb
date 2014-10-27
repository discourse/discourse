require_dependency 'highlighter'

class HighlightController < ApplicationController
  layout false

  skip_before_filter :redirect_to_login_if_required, :check_xhr, :verify_authenticity_token, only: [:show]

  def show

    file = generate_highlight

    #response.headers["Last-Modified"] = File.ctime(file).httpdate
    #response.headers["Content-Length"] = File.size(file).to_s
    #expires_in 1.year, public: true

    if stale?(last_modified: File.ctime(file), public: true)
      expires_in 1.year, public: true
      send_file file, type: 'application/javascript', disposition: nil
    end
  end

  private

  def cache_path
      "public/uploads/"
  end

  def cached_path(key)
    dir = "#{cache_path}"
    FileUtils.mkdir_p(dir)

    "#{dir}highlight_#{key}.js"
  end

  def generate_key(languages)
    Digest::MD5.hexdigest(languages.sort.join('|'))
  end

  def generate_highlight(opts = {})
    languages = SiteSetting.enabled_languages.split('|')

    cached_file_path = cached_path generate_key(languages)
    return cached_file_path if File.exists?(cached_file_path)

    content = Highlighter.generate languages, "public/javascripts/highlight.pack.js"
    File.write(cached_file_path, content) if !File.exists? cached_file_path
    cached_file_path
  end
end
