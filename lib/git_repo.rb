# frozen_string_literal: true

class GitRepo
  attr_reader :path, :name

  def initialize(path, name = nil)
    @path = path
    @name = name
    @memoize = {}
  end

  def valid?
    File.exist?("#{path}/.git")
  end

  def url
    url = run("config --get remote.origin.url")
    return if url.blank?

    url.sub!(/\Agit@github\.com:/, "https://github.com/")
    url.sub!(/\.git\z/, "")
    url
  end

  def latest_local_commit
    run "rev-parse HEAD"
  end

  protected

  def run(cmd)
    @memoize[cmd] ||= begin
      return unless valid?
      stdout, stderr, status = Open3.capture3("git #{cmd}", chdir: path)
      status == 0 ? stdout.strip : nil
    end
  rescue => e
    puts e.inspect
  end
end
