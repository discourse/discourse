# frozen_string_literal: true

module ThemeStore; end

class ThemeStore::GitImporter
  COMMAND_TIMEOUT_SECONDS = 20

  attr_reader :url

  def initialize(url, private_key: nil, branch: nil)
    @url = url
    if @url.start_with?("https://github.com") && !@url.end_with?(".git")
      @url = @url.gsub(/\/$/, '')
      @url += ".git"
    end
    @temp_folder = "#{Pathname.new(Dir.tmpdir).realpath}/discourse_theme_#{SecureRandom.hex}"
    @private_key = private_key
    @branch = branch
  end

  def import!
    if @private_key
      import_private!
    else
      import_public!
    end
    if version = Discourse.find_compatible_git_resource(@temp_folder)
      begin
        execute "git", "cat-file", "-e", version
      rescue RuntimeError => e
        tracking_ref = execute "git", "rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{upstream}"
        remote_name = tracking_ref.split("/", 2)[0]
        execute "git", "fetch", remote_name, "#{version}:#{version}"
      end

      begin
        execute "git", "reset", "--hard", version
      rescue RuntimeError
        raise RemoteTheme::ImportError.new(I18n.t("themes.import_error.git_ref_not_found", ref: version))
      end
    end
  end

  def commits_since(hash)
    commit_hash, commits_behind = nil

    commit_hash = execute("git", "rev-parse", "HEAD").strip
    commits_behind = execute("git", "rev-list", "#{hash}..HEAD", "--count").strip rescue -1

    [commit_hash, commits_behind]
  end

  def version
    execute("git", "rev-parse", "HEAD").strip
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

  def all_files
    Dir.glob("**/*", base: @temp_folder).reject { |f| File.directory?(File.join(@temp_folder, f)) }
  end

  def [](value)
    fullpath = real_path(value)
    return nil unless fullpath
    File.read(fullpath)
  end

  protected

  def import_public!
    begin
      if @branch.present?
        Discourse::Utils.execute_command("git", "clone", "--single-branch", "-b", @branch, @url, @temp_folder)
      else
        Discourse::Utils.execute_command("git", "clone", @url, @temp_folder)
      end
    rescue RuntimeError
      raise RemoteTheme::ImportError.new(I18n.t("themes.import_error.git"))
    end
  end

  def import_private!
    ssh_folder = "#{Pathname.new(Dir.tmpdir).realpath}/discourse_theme_ssh_#{SecureRandom.hex}"
    FileUtils.mkdir_p ssh_folder

    File.write("#{ssh_folder}/id_rsa", @private_key)
    FileUtils.chmod(0600, "#{ssh_folder}/id_rsa")

    begin
      git_ssh_command = { 'GIT_SSH_COMMAND' => "ssh -i #{ssh_folder}/id_rsa -o StrictHostKeyChecking=no" }
      if @branch.present?
        Discourse::Utils.execute_command(git_ssh_command, "git", "clone", "--single-branch", "-b", @branch, @url, @temp_folder)
      else
        Discourse::Utils.execute_command(git_ssh_command, "git", "clone", @url, @temp_folder)
      end
    rescue RuntimeError => err
      raise RemoteTheme::ImportError.new(I18n.t("themes.import_error.git"))
    end
  ensure
    FileUtils.rm_rf ssh_folder
  end

  def execute(*args)
    Discourse::Utils.execute_command(*args, chdir: @temp_folder, timeout: COMMAND_TIMEOUT_SECONDS)
  end
end
