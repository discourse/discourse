# frozen_string_literal: true

RSpec.describe Compression::Engine do
  let(:available_size) { SiteSetting.decompressed_theme_max_file_size_mb }
  let(:folder_name) { "test" }
  let(:temp_folder) do
    path = "#{Pathname.new(Dir.tmpdir).realpath}/#{SecureRandom.hex}"
    FileUtils.mkdir(path)
    path
  end

  before do
    Dir.chdir(temp_folder) do
      FileUtils.mkdir_p("#{folder_name}/a")
      File.write("#{folder_name}/hello.txt", "hello world")
      File.write("#{folder_name}/a/inner", "hello world inner")
    end
  end

  after { FileUtils.rm_rf(temp_folder) }

  it "raises an exception when the file is not supported" do
    unknown_extension = "a_file.crazyext"
    expect {
      described_class.engine_for(unknown_extension)
    }.to raise_error Compression::Engine::UnsupportedFileExtension
  end

  describe "compressing and decompressing files" do
    before do
      Dir.chdir(temp_folder) do
        @compressed_path =
          Compression::Engine.engine_for("#{folder_name}#{extension}").compress(
            temp_folder,
            folder_name,
          )
        FileUtils.rm_rf("#{folder_name}/")
      end
    end

    context "when working with zip files" do
      let(:extension) { ".zip" }

      it "decompresses the folder and inspects files correctly" do
        engine = described_class.engine_for(@compressed_path)

        extract_location = "#{temp_folder}/extract_location"
        FileUtils.mkdir(extract_location)
        engine.decompress(extract_location, "#{temp_folder}/#{folder_name}.zip", available_size)

        expect(read_file("extract_location/hello.txt")).to eq("hello world")
        expect(read_file("extract_location/a/inner")).to eq("hello world inner")
      end

      it "doesn't allow files to be extracted outside the target directory" do
        FileUtils.rm_rf(temp_folder)
        FileUtils.mkdir(temp_folder)

        zip_file = "#{temp_folder}/theme.zip"
        Zip::File.open(zip_file, create: true) do |zipfile|
          zipfile.get_output_stream("child-file") { |f| f.puts("child file") }
          zipfile.get_output_stream("../escape-decompression-folder.txt") do |f|
            f.puts("file that attempts to escape the decompression destination directory")
          end
          zipfile.mkdir("child-dir")
          zipfile.get_output_stream("child-dir/grandchild-file") { |f| f.puts("grandchild file") }
        end

        extract_location = "#{temp_folder}/extract_location"
        FileUtils.mkdir(extract_location)
        engine = described_class.engine_for(zip_file)
        engine.decompress(extract_location, zip_file, available_size)
        Dir.chdir(temp_folder) do
          expect(Dir.glob("**/*")).to contain_exactly(
            "extract_location",
            "extract_location/child-file",
            "extract_location/child-dir",
            "extract_location/child-dir/grandchild-file",
            "theme.zip",
          )
        end
      end

      it "decompresses into symlinked directory" do
        real_location = "#{temp_folder}/extract_location"
        extract_location = "#{temp_folder}/is/symlinked"

        FileUtils.mkdir(real_location)
        FileUtils.mkdir_p(extract_location)
        extract_location = "#{extract_location}/extract_location"
        FileUtils.symlink(real_location, extract_location)

        engine = described_class.engine_for(@compressed_path)
        engine.decompress(extract_location, "#{temp_folder}/#{folder_name}.zip", available_size)

        expect(File.realpath(extract_location)).to eq(real_location)
        expect(read_file("is/symlinked/extract_location/hello.txt")).to eq("hello world")
        expect(read_file("is/symlinked/extract_location/a/inner")).to eq("hello world inner")
      end
    end

    context "when working with .tar.gz files" do
      let(:extension) { ".tar.gz" }

      it "decompresses the folder and inspects files correctly" do
        engine = described_class.engine_for(@compressed_path)

        engine.decompress(temp_folder, "#{temp_folder}/#{folder_name}.tar.gz", available_size)

        expect(read_file("test/hello.txt")).to eq("hello world")
        expect(read_file("test/a/inner")).to eq("hello world inner")
      end

      it "doesn't allow files to be extracted outside the target directory" do
        FileUtils.rm_rf(temp_folder)
        FileUtils.mkdir(temp_folder)

        tar_file = "#{temp_folder}/theme.tar"
        File.open(tar_file, "wb") do |file|
          Gem::Package::TarWriter.new(file) do |tar|
            tar.add_file("child-file", 644) { |tf| tf.write("child file") }
            tar.add_file("../escape-extraction-folder", 644) do |tf|
              tf.write("file that attempts to escape the decompression destination directory")
            end
            tar.mkdir("child-dir", 755)
            tar.add_file("child-dir/grandchild-file", 644) { |tf| tf.write("grandchild file") }
          end
        end
        tar_gz_file = "#{temp_folder}/theme.tar.gz"
        Zlib::GzipWriter.open(tar_gz_file) do |gz|
          gz.orig_name = tar_file
          gz.write(File.binread(tar_file))
        end
        FileUtils.rm(tar_file)

        extract_location = "#{temp_folder}/extract_location"
        FileUtils.mkdir(extract_location)
        engine = described_class.engine_for(tar_gz_file)
        engine.decompress(extract_location, tar_gz_file, available_size)
        Dir.chdir(temp_folder) do
          expect(Dir.glob("**/*")).to contain_exactly(
            "extract_location",
            "extract_location/child-file",
            "extract_location/child-dir",
            "extract_location/child-dir/grandchild-file",
          )
        end
      end

      it "decompresses into symlinked directory" do
        real_location = "#{temp_folder}/extract_location"
        extract_location = "#{temp_folder}/is/symlinked"

        FileUtils.mkdir(real_location)
        FileUtils.mkdir_p(extract_location)
        extract_location = "#{extract_location}/extract_location"
        FileUtils.symlink(real_location, extract_location)

        engine = described_class.engine_for(@compressed_path)
        engine.decompress(extract_location, "#{temp_folder}/#{folder_name}.tar.gz", available_size)

        expect(File.realpath(extract_location)).to eq(real_location)
        expect(read_file("is/symlinked/extract_location/test/hello.txt")).to eq("hello world")
        expect(read_file("is/symlinked/extract_location/test/a/inner")).to eq("hello world inner")
      end
    end

    context "when working with .tar files" do
      let(:extension) { ".tar" }

      it "decompress the folder and inspect files correctly" do
        engine = described_class.engine_for(@compressed_path)

        engine.decompress(temp_folder, "#{temp_folder}/#{folder_name}.tar", available_size)

        expect(read_file("test/hello.txt")).to eq("hello world")
        expect(read_file("test/a/inner")).to eq("hello world inner")
      end
    end
  end

  def read_file(relative_path)
    File.read("#{temp_folder}/#{relative_path}")
  end
end
