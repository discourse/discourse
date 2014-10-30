require_dependency 'highlighter'

class HighlightController < ApplicationController
  layout false

  skip_before_filter :redirect_to_login_if_required, :check_xhr, :verify_authenticity_token, only: [:show]

  def self.generate_key(languages = SiteSetting.enabled_languages.split('|'))
    Digest::MD5.hexdigest(languages.sort.join('|'))
  end

  def self.generate_path(key = generate_key)
    "highlight.js/#{key}"
  end

  def show
    meta = generate_cache
    requested_key = params[:key]

    unless requested_key.nil? or meta[:key].eql? requested_key
      redirect_to action: 'show', key: meta[:key], status: :moved_permanently
      return
    end

    expires_in 1.year, public: true
    if stale?(last_modified: File.ctime(meta[:file]), public: true)
      send_file meta[:file], type: 'application/javascript', disposition: nil
    end
  end

  private

  def cache_path
      "public/uploads/"
  end

  def cached_path(key)
    dir = "#{cache_path}"
    FileUtils.mkdir_p(dir)

    "#{dir}#{HighlightController.generate_path(key).gsub('/', '_')}"
  end

  def generate_cache
    languages = SiteSetting.enabled_languages.split('|')

    key = HighlightController.generate_key(languages)
    cached_file_path = cached_path key
    return {file: cached_file_path, key: key} if File.exists?(cached_file_path)

    content = Highlighter.generate languages, "public/javascripts/highlight.pack.js"
    File.write(cached_file_path, content) if !File.exists? cached_file_path
    return {file: cached_file_path, key: key}
  end
end
