# frozen_string_literal: true

require 'rails_helper'

describe Compression::Engine do
  let(:available_size) { SiteSetting.decompressed_theme_max_file_size_mb }

  before do
    @temp_folder = "#{Pathname.new(Dir.tmpdir).realpath}/#{SecureRandom.hex}"
    @folder_name = 'test'

    FileUtils.mkdir(@temp_folder)
    Dir.chdir(@temp_folder) do
      FileUtils.mkdir_p("#{@folder_name}/a")
      File.write("#{@folder_name}/hello.txt", 'hello world')
      File.write("#{@folder_name}/a/inner", 'hello world inner')
    end
  end

  after { FileUtils.rm_rf @temp_folder }

  it 'raises an exception when the file is not supported' do
    unknown_extension = 'a_file.crazyext'
    expect { described_class.engine_for(unknown_extension) }.to raise_error Compression::Engine::UnsupportedFileExtension
  end

  describe 'compressing and decompressing files' do
    before do
      Dir.chdir(@temp_folder) do
        @compressed_path = Compression::Engine.engine_for("#{@folder_name}#{extension}").compress(@temp_folder, @folder_name)
        FileUtils.rm_rf("#{@folder_name}/")
      end
    end

    context 'working with zip files' do
      let(:extension) { '.zip' }

      it 'decompress the folder and inspect files correctly' do
        engine = described_class.engine_for(@compressed_path)

        engine.decompress(@temp_folder, "#{@temp_folder}/#{@folder_name}.zip", available_size)

        expect(read_file("test/hello.txt")).to eq("hello world")
        expect(read_file("test/a/inner")).to eq("hello world inner")
      end
    end

    context 'working with .tar.gz files' do
      let(:extension) { '.tar.gz' }

      it 'decompress the folder and inspect files correctly' do
        engine = described_class.engine_for(@compressed_path)

        engine.decompress(@temp_folder, "#{@temp_folder}/#{@folder_name}.tar.gz", available_size)

        expect(read_file("test/hello.txt")).to eq("hello world")
        expect(read_file("test/a/inner")).to eq("hello world inner")
      end
    end

    context 'working with .tar files' do
      let(:extension) { '.tar' }

      it 'decompress the folder and inspect files correctly' do
        engine = described_class.engine_for(@compressed_path)

        engine.decompress(@temp_folder, "#{@temp_folder}/#{@folder_name}.tar", available_size)

        expect(read_file("test/hello.txt")).to eq("hello world")
        expect(read_file("test/a/inner")).to eq("hello world inner")
      end
    end
  end

  def read_file(relative_path)
    File.read("#{@temp_folder}/#{relative_path}")
  end
end
