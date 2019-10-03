
# encoding: utf-8
# frozen_string_literal: true

require 'rails_helper'
require 'theme_store/zip_importer'

describe ThemeStore::ZipImporter do
  before do
    @temp_folder = "#{Pathname.new(Dir.tmpdir).realpath}/discourse_theme_#{SecureRandom.hex}"

    FileUtils.mkdir(@temp_folder)
    Dir.chdir(@temp_folder) do
      FileUtils.mkdir_p('test/a')
      File.write("test/hello.txt", "hello world")
      File.write("test/a/inner", "hello world inner")
    end
  end

  after do
    FileUtils.rm_rf @temp_folder
  end

  it "can import a simple zipped theme" do
    Dir.chdir(@temp_folder) do
      Compression::Zip.new.compress(@temp_folder, 'test')
      FileUtils.rm_rf('test/')
    end

    file_name = 'test.zip'
    importer = ThemeStore::ZipImporter.new("#{@temp_folder}/#{file_name}", file_name)
    importer.import!

    expect(importer["hello.txt"]).to eq("hello world")
    expect(importer["a/inner"]).to eq("hello world inner")

    importer.cleanup!
  end

  it "can import a simple gzipped theme" do
    Dir.chdir(@temp_folder) do
      `tar -cvzf test.tar.gz test/* 2> /dev/null`
    end

    file_name = 'test.tar.gz'
    importer = ThemeStore::ZipImporter.new("#{@temp_folder}/#{file_name}", file_name)
    importer.import!

    expect(importer["hello.txt"]).to eq("hello world")
    expect(importer["a/inner"]).to eq("hello world inner")

    importer.cleanup!
  end
end
