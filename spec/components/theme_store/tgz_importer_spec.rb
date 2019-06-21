
# encoding: utf-8
# frozen_string_literal: true

require 'rails_helper'
require 'theme_store/tgz_importer'
require 'zip'

describe ThemeStore::TgzImporter do
  before do
    @temp_folder = "#{Pathname.new(Dir.tmpdir).realpath}/discourse_theme_#{SecureRandom.hex}"

    FileUtils.mkdir(@temp_folder)
    Dir.chdir(@temp_folder) do
      FileUtils.mkdir('test/')
      File.write("test/hello.txt", "hello world")
      FileUtils.mkdir('test/a')
      File.write("test/a/inner", "hello world inner")
    end
  end

  after do
    FileUtils.rm_rf @temp_folder
  end

  it "can import a simple zipped theme" do
    Dir.chdir(@temp_folder) do
      `tar -cvf test.tar test/* 2> /dev/null`

      Zip::File.open('test.tar.zip', Zip::File::CREATE) do |zipfile|
        zipfile.add('test.tar', "#{@temp_folder}/test.tar")
        zipfile.close
      end
    end

    importer = ThemeStore::TgzImporter.new("#{@temp_folder}/test.tar.zip")
    importer.import!

    expect(importer["hello.txt"]).to eq("hello world")
    expect(importer["a/inner"]).to eq("hello world inner")

    importer.cleanup!
  end

  it "can import a simple gzipped theme" do
    Dir.chdir(@temp_folder) do
      `tar -cvzf test.tar.gz test/* 2> /dev/null`
    end

    importer = ThemeStore::TgzImporter.new("#{@temp_folder}/test.tar.gz")
    importer.import!

    expect(importer["hello.txt"]).to eq("hello world")
    expect(importer["a/inner"]).to eq("hello world inner")

    importer.cleanup!
  end
end
