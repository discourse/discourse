# frozen_string_literal: true

module ThemeStore; end

class ThemeStore::GitImporter
  COMMAND_TIMEOUT_SECONDS = 20

  attr_reader :url

  def initialize(url, private_key: nil, branch: nil)
    @url = GitUrl.normalize(url)
    @temp_folder = "#{Pathname.new(Dir.tmpdir).realpath}/discourse_theme_#{SecureRandom.hex}"
    @private_key = private_key
    @branch = branch
  end

  def import!
    clone!

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

  def raise_import_error!
    raise RemoteTheme::ImportError.new(I18n.t("themes.import_error.git"))
  end

  def clone!
    begin
      @uri = URI.parse(@url)
    rescue URI::Error
      raise_import_error!
    end

    case @uri&.scheme
    when "http", "https"
      clone_http!
    when "ssh"
      clone_ssh!
    else
      raise RemoteTheme::ImportError.new(I18n.t("themes.import_error.git_unsupported_scheme"))
    end
  end

  def clone_args(config = {})
    args = ["git"]

    config.each do |key, value|
      args.concat(['-c', "#{key}=#{value}"])
    end

    args << "clone"

    if @branch.present?
      args.concat(["-b", @branch])
    end

    args.concat([@url, @temp_folder])

    args
  end

  def clone_http!
    uris = [@uri]

    begin
      resolved_uri = FinalDestination.resolve(@uri.to_s)
      if resolved_uri && resolved_uri != @uri
        uris.unshift(resolved_uri)
      end
    rescue
      # If this fails, we can stil attempt to clone using the original URI
    end

    uris.each do |uri|
      @uri = uri
      @url = @uri.to_s

      unless ["http", "https"].include?(@uri.scheme)
        raise_import_error!
      end

      addresses = FinalDestination::SSRFDetector.lookup_and_filter_ips(@uri.host)

      unless addresses.empty?
        env = { "GIT_TERMINAL_PROMPT" => "0" }

        args = clone_args(
          "http.followRedirects" => "false",
          "http.curloptResolve" => "#{@uri.host}:#{@uri.port}:#{addresses.join(',')}",
        )

        begin
          Discourse::Utils.execute_command(env, *args, timeout: COMMAND_TIMEOUT_SECONDS)
          return
        rescue RuntimeError
        end
      end
    end

    raise_import_error!
  end

  def clone_ssh!
    unless @private_key.present?
      raise_import_error!
    end

    with_ssh_private_key do |ssh_folder|
      # Use only the specified SSH key
      env = { 'GIT_SSH_COMMAND' => "ssh -i #{ssh_folder}/id_rsa -o IdentitiesOnly=yes -o IdentityFile=#{ssh_folder}/id_rsa -o StrictHostKeyChecking=no" }
      args = clone_args

      begin
        Discourse::Utils.execute_command(env, *args, timeout: COMMAND_TIMEOUT_SECONDS)
      rescue RuntimeError
        raise_import_error!
      end
    end
  end

  def with_ssh_private_key
    ssh_folder = "#{Pathname.new(Dir.tmpdir).realpath}/discourse_theme_ssh_#{SecureRandom.hex}"
    FileUtils.mkdir_p ssh_folder

    File.write("#{ssh_folder}/id_rsa", @private_key)
    FileUtils.chmod(0600, "#{ssh_folder}/id_rsa")

    yield ssh_folder
  ensure
    FileUtils.rm_rf ssh_folder
  end

  def execute(*args)
    Discourse::Utils.execute_command(*args, chdir: @temp_folder, timeout: COMMAND_TIMEOUT_SECONDS)
  end
end
