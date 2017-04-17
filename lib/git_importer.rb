class GitImporter

  attr_reader :url

  def initialize(url)
    @url = url
    if @url.start_with?("https://github.com") && !@url.end_with?(".git")
      @url += ".git"
    end
    @temp_folder = "#{Pathname.new(Dir.tmpdir).realpath}/discourse_theme_#{SecureRandom.hex}"
  end

  def import!
    Discourse::Utils.execute_command("git", "clone", @url, @temp_folder)
  end

  def commits_since(hash)
    commit_hash, commits_behind = nil

    Dir.chdir(@temp_folder) do
      commit_hash = Discourse::Utils.execute_command("git", "rev-parse", "HEAD").strip
      commits_behind = Discourse::Utils.execute_command("git", "rev-list", "#{hash}..HEAD", "--count").strip
    end

    [commit_hash, commits_behind]
  end

  def version
    Dir.chdir(@temp_folder) do
      Discourse::Utils.execute_command("git", "rev-parse", "HEAD").strip
    end
  end

  def cleanup!
    FileUtils.rm_rf(@temp_folder)
  end

  def [](value)
    fullpath = "#{@temp_folder}/#{value}"
    return nil unless File.exist?(fullpath)

    # careful to handle symlinks here, don't want to expose random data
    fullpath = Pathname.new(fullpath).realpath.to_s
    if fullpath && fullpath.start_with?(@temp_folder)
      File.read(fullpath)
    end
  end

end
