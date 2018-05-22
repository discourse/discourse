class HandleChunkUpload

  def initialize(chunk, params = {})
    @chunk = chunk
    @params = params
  end

  def self.check_chunk(chunk, params)
    HandleChunkUpload.new(chunk, params).check_chunk
  end

  def self.upload_chunk(chunk, params)
    HandleChunkUpload.new(chunk, params).upload_chunk
  end

  def self.merge_chunks(chunk, params)
    HandleChunkUpload.new(chunk, params).merge_chunks
  end

  def check_chunk
    # check whether the chunk has already been uploaded
    has_chunk_been_uploaded = File.exists?(@chunk) && File.size(@chunk) == @params[:current_chunk_size]
    # 200 = exists, 404 = not uploaded yet
    status = has_chunk_been_uploaded ? 200 : 404
  end

  def upload_chunk
    # path to chunk file
    dir = File.dirname(@chunk)
    # ensure directory exists
    FileUtils.mkdir_p(dir) unless Dir.exists?(dir)
    # save chunk to the directory
    File.open(@chunk, "wb") { |f| f.write(@params[:file].tempfile.read) }
  end

  def merge_chunks
    upload_path     = @params[:upload_path]
    tmp_upload_path = @params[:tmp_upload_path]
    model           = @params[:model]
    identifier      = @params[:identifier]
    filename        = @params[:filename]
    tmp_directory   = @params[:tmp_directory]

    # delete destination files
    begin
      File.delete(upload_path)
      File.delete(tmp_upload_path)
    rescue Errno::ENOENT
    end

    # merge all the chunks
    File.open(tmp_upload_path, "a") do |file|
      (1..@chunk).each do |chunk_number|
        # path to chunk
        chunk_path = model.chunk_path(identifier, filename, chunk_number)
        # add chunk to file
        file << File.open(chunk_path).read
      end
    end

    # rename tmp file to final file name
    FileUtils.mv(tmp_upload_path, upload_path, force: true)

    # remove tmp directory
    begin
      FileUtils.rm_rf(tmp_directory)
    rescue Errno::ENOENT
    end
  end

end
