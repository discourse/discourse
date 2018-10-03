
# encoding: utf-8

require 'rails_helper'
require 'theme_store/git_importer'

describe ThemeStore::GitImporter do

  context "#import" do

    let(:url) { "https://github.com/example/example.git" }
    let(:ssh_url) { "git@github.com:example/example.git" }
    let(:branch) { "dev" }

    before do
      hex = "xxx"
      SecureRandom.stubs(:hex).returns(hex)
      @temp_folder = "#{Pathname.new(Dir.tmpdir).realpath}/discourse_theme_#{hex}"
      @ssh_folder = "#{Pathname.new(Dir.tmpdir).realpath}/discourse_theme_ssh_#{hex}"
    end

    it "should import from http url" do
      Discourse::Utils.expects(:execute_command).with("git", "clone", url, @temp_folder)

      importer = ThemeStore::GitImporter.new(url)
      importer.import!
    end

    it "should import from ssh url" do
      Discourse::Utils.expects(:execute_command).with({
        'GIT_SSH_COMMAND' => "ssh -i #{@ssh_folder}/id_rsa -o StrictHostKeyChecking=no"
      }, "git", "clone", ssh_url, @temp_folder)

      importer = ThemeStore::GitImporter.new(ssh_url, private_key: "private_key")
      importer.import!
    end

    it "should import branch from http url" do
      Discourse::Utils.expects(:execute_command).with("git", "clone", "--single-branch", "-b", branch, url, @temp_folder)

      importer = ThemeStore::GitImporter.new(url, branch: branch)
      importer.import!
    end

    it "should import branch from ssh url" do
      Discourse::Utils.expects(:execute_command).with({
        'GIT_SSH_COMMAND' => "ssh -i #{@ssh_folder}/id_rsa -o StrictHostKeyChecking=no"
      }, "git", "clone", "--single-branch", "-b", branch, ssh_url, @temp_folder)

      importer = ThemeStore::GitImporter.new(ssh_url, private_key: "private_key", branch: branch)
      importer.import!
    end
  end
end
