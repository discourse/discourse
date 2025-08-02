# frozen_string_literal: true

class ThemeStore::GitImporter < ThemeStore::BaseImporter
  COMMAND_TIMEOUT_SECONDS = 20

  attr_reader :url

  def initialize(url, private_key: nil, branch: nil)
    @url = GitUrl.normalize(url)
    @private_key = private_key
    @branch = branch
  end

  def import!
    clone!

    if version = Discourse.find_compatible_git_resource(temp_folder)
      begin
        execute "git", "cat-file", "-e", version
      rescue RuntimeError => e
        tracking_ref =
          execute "git", "rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{upstream}"
        remote_name = tracking_ref.split("/", 2)[0]
        execute "git", "fetch", remote_name, "#{version}:#{version}"
      end

      begin
        execute "git", "reset", "--hard", version
      rescue RuntimeError
        raise RemoteTheme::ImportError.new(
                I18n.t("themes.import_error.git_ref_not_found", ref: version),
              )
      end
    end
  end

  def commits_since(hash)
    commit_hash, commits_behind = nil

    commit_hash = execute("git", "rev-parse", "HEAD").strip
    commits_behind =
      begin
        execute("git", "rev-list", "#{hash}..HEAD", "--count").strip
      rescue StandardError
        -1
      end

    [commit_hash, commits_behind]
  end

  def version
    execute("git", "rev-parse", "HEAD").strip
  end

  protected

  def redirected_uri
    first_clone_uri = @uri.dup
    first_clone_uri.path.gsub!(%r{/\z}, "")
    first_clone_uri.path += "/info/refs"
    first_clone_uri.query = "service=git-upload-pack"

    redirected_uri = FinalDestination.resolve(first_clone_uri.to_s, http_verb: :get)

    if redirected_uri&.path&.ends_with?("/info/refs")
      redirected_uri.path.gsub!(%r{/info/refs\z}, "")
      redirected_uri.query = nil
      redirected_uri
    else
      @uri
    end
  rescue StandardError
    @uri
  end

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

  def clone_args(url, config = {})
    args = ["git"]

    config.each { |key, value| args.concat(["-c", "#{key}=#{value}"]) }

    args << "clone"

    args.concat(["--single-branch", "-b", @branch]) if @branch.present?

    args.concat([url, temp_folder])

    args
  end

  def clone_http!
    uri = redirected_uri

    raise_import_error! if %w[http https].exclude?(@uri.scheme)

    addresses = FinalDestination::SSRFDetector.lookup_and_filter_ips(uri.host)

    raise_import_error! if addresses.empty?

    env = { "GIT_TERMINAL_PROMPT" => "0" }

    args =
      clone_args(
        uri.to_s,
        "http.followRedirects" => "false",
        "http.curloptResolve" => "#{uri.host}:#{uri.port}:#{addresses.join(",")}",
      )

    begin
      Discourse::Utils.execute_command(env, *args, timeout: COMMAND_TIMEOUT_SECONDS)
    rescue RuntimeError
      raise_import_error!
    end
  end

  def clone_ssh!
    raise_import_error! if @private_key.blank?

    with_ssh_private_key do |ssh_folder|
      # Use only the specified SSH key
      env = {
        "GIT_SSH_COMMAND" =>
          "ssh -i #{ssh_folder}/id_rsa -o IdentitiesOnly=yes -o IdentityFile=#{ssh_folder}/id_rsa -o StrictHostKeyChecking=no",
      }
      args = clone_args(@url)

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
    Discourse::Utils.execute_command(*args, chdir: temp_folder, timeout: COMMAND_TIMEOUT_SECONDS)
  end
end
