# encoding: utf-8
# frozen_string_literal: true

require "theme_store/git_importer"

RSpec.describe ThemeStore::GitImporter do
  describe "#import" do
    let(:url) { "https://github.com/example/example.git" }
    let(:first_fetch_url) do
      "https://github.com/example/example.git/info/refs?service=git-upload-pack"
    end
    let(:trailing_slash_url) { "https://github.com/example/example/" }
    let(:ssh_url) { "git@github.com:example/example.git" }
    let(:branch) { "dev" }

    before do
      hex = "xxx"
      SecureRandom.stubs(:hex).returns(hex)

      FinalDestination::SSRFDetector
        .stubs(:lookup_and_filter_ips)
        .with("github.com")
        .returns(["192.0.2.100"])

      @temp_folder = "#{Pathname.new(Dir.tmpdir).realpath}/discourse_theme_#{hex}"
      @ssh_folder = "#{Pathname.new(Dir.tmpdir).realpath}/discourse_theme_ssh_#{hex}"
    end

    it "reports safe reasons for Git command failures" do
      failures = {
        "Permission denied (publickey)." => "themes.import_error.git_authentication",
        "fatal: Remote branch missing not found in upstream origin" =>
          "themes.import_error.git_branch_not_found",
        "ERROR: Repository not found." => "themes.import_error.git_repository_not_found",
      }

      failures.each do |stderr, translation_key|
        status = stub(exited?: true, exitstatus: 128)
        error = Discourse::Utils::CommandError.new("Git failed", stderr: stderr, status: status)
        Discourse::Utils.stubs(:execute_command).raises(error)

        importer = ThemeStore::GitImporter.new(ssh_url, private_key: "private_key")

        expect { importer.import! }.to raise_error(
          RemoteTheme::ImportError,
          I18n.t(translation_key),
        )
      end

      timeout_status = stub(exited?: true, exitstatus: 124)
      timeout_error =
        Discourse::Utils::CommandError.new("Git timed out", stderr: "", status: timeout_status)
      Discourse::Utils.stubs(:execute_command).raises(timeout_error)

      importer = ThemeStore::GitImporter.new(ssh_url, private_key: "private_key")

      expect { importer.import! }.to raise_error(
        RemoteTheme::ImportError,
        I18n.t("themes.import_error.git_timeout"),
      )
    end

    it "imports ssh urls" do
      Discourse::Utils.expects(:execute_command).with(
        {
          "GIT_SSH_COMMAND" =>
            "ssh -i #{@ssh_folder}/id_rsa -o IdentitiesOnly=yes -o IdentityFile=#{@ssh_folder}/id_rsa -o StrictHostKeyChecking=no",
        },
        "git",
        "clone",
        "ssh://git@github.com/example/example.git",
        @temp_folder,
        timeout: 20,
      )

      importer = ThemeStore::GitImporter.new(ssh_url, private_key: "private_key")
      importer.import!
    end

    it "imports ssh urls with a particular branch" do
      Discourse::Utils.expects(:execute_command).with(
        {
          "GIT_SSH_COMMAND" =>
            "ssh -i #{@ssh_folder}/id_rsa -o IdentitiesOnly=yes -o IdentityFile=#{@ssh_folder}/id_rsa -o StrictHostKeyChecking=no",
        },
        "git",
        "clone",
        "--single-branch",
        "-b",
        branch,
        "ssh://git@github.com/example/example.git",
        @temp_folder,
        timeout: 20,
      )

      importer = ThemeStore::GitImporter.new(ssh_url, private_key: "private_key", branch: branch)
      importer.import!
    end

    context "with a redirect" do
      before do
        FinalDestination
          .stubs(:resolve)
          .with(first_fetch_url, http_verb: :get)
          .returns(
            URI.parse(
              "https://github.com/redirected/example.git/info/refs?service=git-upload-pack",
            ),
          )
      end

      it "imports http urls" do
        Discourse::Utils.expects(:execute_command).with(
          { "GIT_TERMINAL_PROMPT" => "0" },
          "git",
          "-c",
          "http.followRedirects=false",
          "-c",
          "http.curloptResolve=github.com:443:192.0.2.100",
          "clone",
          "https://github.com/redirected/example.git",
          @temp_folder,
          timeout: 20,
        )

        importer = ThemeStore::GitImporter.new(url)
        importer.import!

        expect(importer.url).to eq(url)
      end
    end

    context "without a redirect" do
      before do
        FinalDestination
          .stubs(:resolve)
          .with(first_fetch_url, http_verb: :get)
          .returns(URI.parse(first_fetch_url))
      end

      it "imports http urls" do
        Discourse::Utils.expects(:execute_command).with(
          { "GIT_TERMINAL_PROMPT" => "0" },
          "git",
          "-c",
          "http.followRedirects=false",
          "-c",
          "http.curloptResolve=github.com:443:192.0.2.100",
          "clone",
          "https://github.com/example/example.git",
          @temp_folder,
          timeout: 20,
        )

        importer = ThemeStore::GitImporter.new(url)
        importer.import!
      end

      it "imports when the url has a trailing slash" do
        Discourse::Utils.expects(:execute_command).with(
          { "GIT_TERMINAL_PROMPT" => "0" },
          "git",
          "-c",
          "http.followRedirects=false",
          "-c",
          "http.curloptResolve=github.com:443:192.0.2.100",
          "clone",
          "https://github.com/example/example.git",
          @temp_folder,
          timeout: 20,
        )

        importer = ThemeStore::GitImporter.new(trailing_slash_url)
        importer.import!
      end

      it "imports http urls with a particular branch" do
        Discourse::Utils.expects(:execute_command).with(
          { "GIT_TERMINAL_PROMPT" => "0" },
          "git",
          "-c",
          "http.followRedirects=false",
          "-c",
          "http.curloptResolve=github.com:443:192.0.2.100",
          "clone",
          "--single-branch",
          "-b",
          branch,
          "https://github.com/example/example.git",
          @temp_folder,
          timeout: 20,
        )

        importer = ThemeStore::GitImporter.new(url, branch: branch)
        importer.import!
      end
    end
  end
end
