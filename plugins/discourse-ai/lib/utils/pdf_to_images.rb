# frozen_string_literal: true

class DiscourseAi::Utils::PdfToImages
  MAX_PDF_SIZE = 100.megabytes
  # this is long, mutool can be faster than magick, 10 minutes will be enough for quite large pdfs
  MAX_CONVERT_SECONDS = 600
  BACKOFF_SECONDS = [5, 30, 60]

  attr_reader :upload, :user

  def initialize(upload:, user:)
    @upload = upload
    @user = user
    @uploaded_pages = UploadReference.where(target: upload).map(&:upload).presence
  end

  def uploaded_pages
    @uploaded_pages ||= extract_pages
  end

  def extract_pages
    begin
      pdf_path =
        if upload.local?
          Discourse.store.path_for(upload)
        else
          Discourse.store.download_safe(upload, max_file_size_kb: MAX_PDF_SIZE)&.path
        end

      raise Discourse::InvalidParameters.new("Failed to download PDF") if pdf_path.nil?

      temp_dir = Dir.mktmpdir("discourse-pdf-#{SecureRandom.hex(8)}")
      temp_pdf = File.join(temp_dir, "source.pdf")
      FileUtils.cp(pdf_path, temp_pdf)

      # Convert PDF to individual page images
      output_pattern = File.join(temp_dir, "page-%04d.png")

      command = [
        "magick",
        "-density",
        "300",
        temp_pdf,
        "-background",
        "white",
        "-auto-orient",
        "-quality",
        "85",
        output_pattern,
      ]

      Discourse::Utils.execute_command(
        *command,
        failure_message: "Failed to convert PDF to images",
        timeout: MAX_CONVERT_SECONDS,
      )

      uploads = []
      Dir
        .glob(File.join(temp_dir, "page-*.png"))
        .sort
        .each do |page_path|
          upload =
            UploadCreator.new(File.open(page_path), "page-#{File.basename(page_path)}").create_for(
              @user.id,
            )

          uploads << upload
        end

      # Create upload references
      UploadReference.ensure_exist!(upload_ids: uploads.map(&:id), target: @upload)

      @uploaded_pages = uploads
    ensure
      FileUtils.rm_rf(temp_dir) if temp_dir
    end
  end
end
