
# encoding: utf-8

require 'rails_helper'
require 'theme_store/tgz_importer'

describe ThemeStore::TgzImporter do
  before do
    @temp_folder = "#{Pathname.new(Dir.tmpdir).realpath}/discourse_theme_#{SecureRandom.hex}"
  end

  after do
    FileUtils.rm_rf @temp_folder
  end

  it "can import a simple theme" do

    FileUtils.mkdir(@temp_folder)

    Dir.chdir(@temp_folder) do
      FileUtils.mkdir('test/')
      File.write("test/hello.txt", "hello world")
      FileUtils.mkdir('test/a')
      File.write("test/a/inner", "hello world inner")

      `tar -cvzf test.tar.gz test/*`
    end

    importer = ThemeStore::TgzImporter.new("#{@temp_folder}/test.tar.gz")
    importer.import!

    expect(importer["hello.txt"]).to eq("hello world")
    expect(importer["a/inner"]).to eq("hello world inner")

    importer.cleanup!
  end
end
