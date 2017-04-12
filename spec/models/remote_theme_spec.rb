require 'rails_helper'

describe RemoteTheme do
  context '#import_remote' do
    def setup_git_repo(files)
      dir = Dir.tmpdir
      repo_dir = "#{dir}/#{SecureRandom.hex}"
      `mkdir #{repo_dir}`
      `cd #{repo_dir} && git init . `
      `cd #{repo_dir} && git config user.email 'someone@cool.com'`
      `cd #{repo_dir} && git config user.name 'The Cool One'`
      `cd #{repo_dir} && mkdir desktop mobile common`
      files.each do |name, data|
        File.write("#{repo_dir}/#{name}", data)
        `cd #{repo_dir} && git add #{name}`
      end
      `cd #{repo_dir} && git commit -am 'first commit'`
      repo_dir
    end

    let :initial_repo do
      setup_git_repo(
        "about.json" => '{
          "name": "awesome theme",
          "about_url": "https://www.site.com/about",
          "license_url": "https://www.site.com/license"
        }',
        "desktop/desktop.scss" => "body {color: red;}",
        "common/header.html" => "I AM HEADER",
        "common/random.html" => "I AM SILLY",
        "common/embedded.scss" => "EMBED",
      )
    end

    after do
      `rm -fr #{initial_repo}`
    end

    it 'can correctly import a remote theme' do

      time = Time.new('2000')
      freeze_time time

      @theme = RemoteTheme.import_theme(initial_repo)
      remote = @theme.remote_theme

      expect(@theme.name).to eq('awesome theme')
      expect(remote.remote_url).to eq(initial_repo)
      expect(remote.remote_version).to eq(`cd #{initial_repo} && git rev-parse HEAD`.strip)
      expect(remote.local_version).to eq(`cd #{initial_repo} && git rev-parse HEAD`.strip)

      expect(remote.about_url).to eq("https://www.site.com/about")
      expect(remote.license_url).to eq("https://www.site.com/license")

      expect(@theme.theme_fields.length).to eq(3)

      mapped = Hash[*@theme.theme_fields.map{|f| ["#{f.target}-#{f.name}", f.value]}.flatten]

      expect(mapped["0-header"]).to eq("I AM HEADER")
      expect(mapped["1-scss"]).to eq("body {color: red;}")
      expect(mapped["0-embedded_scss"]).to eq("EMBED")

      expect(remote.remote_updated_at).to eq(time)

      File.write("#{initial_repo}/common/header.html", "I AM UPDATED")
      `cd #{initial_repo} && git commit -am "update"`

      time = Time.new('2001')
      freeze_time time

      remote.update_remote_version
      expect(remote.commits_behind).to eq(1)
      expect(remote.remote_version).to eq(`cd #{initial_repo} && git rev-parse HEAD`.strip)


      remote.update_from_remote
      @theme.save
      @theme.reload

      mapped = Hash[*@theme.theme_fields.map{|f| ["#{f.target}-#{f.name}", f.value]}.flatten]

      expect(mapped["0-header"]).to eq("I AM UPDATED")
      expect(mapped["1-scss"]).to eq("body {color: red;}")
      expect(remote.remote_updated_at).to eq(time)

    end
  end
end
