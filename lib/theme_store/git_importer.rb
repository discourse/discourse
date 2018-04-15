module ThemeStore; end

class ThemeStore::GitImporter

  attr_reader :url

  def initialize(url, private_key: nil)
    @url = url
    if @url.start_with?("https://github.com") && !@url.end_with?(".git")
      @url += ".git"
    end
    @temp_folder = "#{Pathname.new(Dir.tmpdir).realpath}/discourse_theme_#{SecureRandom.hex}"
    @private_key = private_key
  end

  def import!
    if @private_key
      import_private!
    else
      import_public!
    end
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

  def real_path(relative)
    fullpath = "#{@temp_folder}/#{relative}"
    return nil unless File.exist?(fullpath)

    # careful to handle symlinks here, don't want to expose random data
    fullpath = Pathname.new(fullpath).realpath.to_s

    if fullpath && fullpath.start_with?(@temp_folder)
      fullpath
    else
      nil
    end
  end

  def [](value)
    fullpath = real_path(value)
    return nil unless fullpath
    File.read(fullpath)
  end

  protected

  def import_public!
    Discourse::Utils.execute_command("git", "clone", @url, @temp_folder)
  end

  def import_private!
    ssh_folder = "#{Pathname.new(Dir.tmpdir).realpath}/discourse_theme_ssh_#{SecureRandom.hex}"
    FileUtils.mkdir_p ssh_folder

    Dir.chdir(ssh_folder) do
      File.write('id_rsa', @private_key.strip)
      FileUtils.chmod(0600, 'id_rsa')
    end

    Discourse::Utils.execute_command({
      'GIT_SSH_COMMAND' => "ssh -i #{ssh_folder}/id_rsa -o StrictHostKeyChecking=no"
    }, "git", "clone", @url, @temp_folder)
  ensure
    FileUtils.rm_rf ssh_folder
  end

end
