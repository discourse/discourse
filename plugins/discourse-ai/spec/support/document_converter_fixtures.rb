# frozen_string_literal: true

module DocumentConverterFixtures
  def with_document_file(extension, contents)
    tempfile = Tempfile.new(["document", ".#{extension}"])
    tempfile.binmode
    tempfile.write(contents)
    tempfile.rewind

    yield tempfile.path
  ensure
    tempfile&.close!
  end

  def with_zipped_document(extension, entries)
    tempfile = Tempfile.new(["document", ".#{extension}"])
    path = tempfile.path
    tempfile.close
    FileUtils.rm_f(path)

    ::Zip::File.open(path, create: true) do |zip_file|
      entries.each do |name, content|
        zip_file.get_output_stream(name) { |stream| stream.write(content) }
      end
    end

    yield path
  ensure
    tempfile&.close
    FileUtils.rm_f(path) if path
  end

  def zipped_document_bytes(extension, entries)
    with_zipped_document(extension, entries) { |path| File.binread(path) }
  end
end

RSpec.configure { |config| config.include DocumentConverterFixtures }
