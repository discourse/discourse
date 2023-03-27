# frozen_string_literal: true

class MockGitImporter < ThemeStore::GitImporter
  attr_reader :s3_client

  class << self
    def with_mock
      git_importer = ThemeStore::GitImporter
      ThemeStore.send(:remove_const, :GitImporter)
      ThemeStore.const_set(:GitImporter, MockGitImporter)

      begin
        yield
      ensure
        ThemeStore.send(:remove_const, :GitImporter)
        ThemeStore.const_set(:GitImporter, git_importer)
      end
    end

    def register(url, path)
      repos[url] = path
      url
    end

    def [](url)
      repos.fetch(url)
    end

    def reset!
      repos = nil
    end

    private

    def repos
      @repos ||= {}
    end
  end

  def initialize(url, private_key: nil, branch: nil)
    @url = url
    @private_key = private_key
    @branch = branch
    @temp_folder = "#{Pathname.new(Dir.tmpdir).realpath}/discourse_theme_#{SecureRandom.hex}"
  end

  def import!
    begin
      path = MockGitImporter[@url]
    rescue KeyError
      raise_import_error!
    end

    Discourse::Utils.execute_command("git", "clone", path, @temp_folder)
  end
end
