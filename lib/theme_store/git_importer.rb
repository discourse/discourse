# frozen_string_literal: true

module ThemeStore; end

class ThemeStore::GitImporter
  COMMAND_TIMEOUT_SECONDS = 20

  attr_reader :url

  def initialize(url, private_key: nil, branch: nil)
    @url = url
    @clone_url = GitUrl.normalize(url)
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
      @clone_uri = URI.parse(@clone_url)
    rescue URI::Error
      raise_import_error!
    end

    case @clone_uri&.scheme
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
      args.concat(["--single-branch", "-b", @branch])
    end

    args.concat([@clone_url, @temp_folder])

    args
  end

  def clone_http!
    begin
      @clone_uri = FinalDestination.resolve(@clone_uri.to_s)
    rescue
      raise_import_error!
    end

    @clone_url = @clone_uri.to_s

    unless ["http", "https"].include?(@clone_uri.scheme)
      raise_import_error!
    end

    begin
      addresses = FinalDestination::SSRFDetector.lookup_and_filter_ips(@clone_uri.host)
    rescue FinalDestination::SSRFDetector::DisallowedIpError
      raise_import_error!
    end

    if addresses.empty?
      raise_import_error!
    end

    env = { "GIT_TERMINAL_PROMPT" => "0" }

    args = clone_args(
      "http.followRedirects" => "false",
      "http.curloptResolve" => "#{@clone_uri.host}:#{@clone_uri.port}:#{addresses.join(',')}",
    )

    begin
      Discourse::Utils.execute_command(env, *args, timeout: COMMAND_TIMEOUT_SECONDS)
    rescue RuntimeError
      raise_import_error!
    end
  end

  def clone_ssh!
    unless @private_key.present?
      raise_import_error!
    end

    with_ssh_private_key do |ssh_folder|
      # Use only the specified SSH key
      env = { 'GIT_SSH_COMMAND' => "ssh -i #{ssh_folder}/id_rsa -o IdentitiesOnly=yes -o IdentityFile=#{ssh_folder}/id_rsa -o StrictHostKeyChecking=no" }

      begin
        addresses = FinalDestination::SSRFDetector.lookup_and_filter_ips(@clone_uri.host)
      rescue FinalDestination::SSRFDetector::DisallowedIpError
        raise_import_error!
      end

      timeout_at = Time.zone.now + COMMAND_TIMEOUT_SECONDS

      addresses.each do |address|
        remaining_timeout = timeout_at - Time.zone.now
        raise_import_error! if remaining_timeout < 0

        @clone_uri.host = address
        @clone_url = @clone_uri.to_s

        args = clone_args

        begin
          return Discourse::Utils.execute_command(env, *args, timeout: remaining_timeout)
        rescue RuntimeError
        end
      end

      raise_import_error!
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
