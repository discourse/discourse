# For converting urls to files
class UriAdapter

  attr_reader :target, :content, :tempfile, :original_filename

  def initialize(target)
    raise Discourse::InvalidParameters unless target =~ /^https?:\/\//

    @target = URI(target)
    @original_filename = ::File.basename(@target.path)
    @content = download_content
    @tempfile = TempfileFactory.new.generate(@original_filename)
  end

  def download_content
    open(target)
  end

  def copy_to_tempfile(src)
    while data = src.read(16*1024)
      tempfile.write(data)
    end
    src.close
    tempfile.rewind
    tempfile
  end

  def file_size
    content.size
  end

  def build_uploaded_file
    return if (SiteSetting.max_image_size_kb * 1024) < file_size

    copy_to_tempfile(content)
    content_type = content.content_type if content.respond_to?(:content_type)
    content_type ||= "text/html"

    ActionDispatch::Http::UploadedFile.new( tempfile: tempfile,
                                            filename: original_filename,
                                            type: content_type
                                            )
  end
end

# From https://github.com/thoughtbot/paperclip/blob/master/lib/paperclip/tempfile_factory.rb
class TempfileFactory
  ILLEGAL_FILENAME_CHARACTERS = /^~/

  def generate(name)
    @name = name
    file = Tempfile.new([basename, extension])
    file.binmode
    file
  end

  def extension
    File.extname(@name)
  end

  def basename
    File.basename(@name, extension).gsub(ILLEGAL_FILENAME_CHARACTERS, '_')
  end
end