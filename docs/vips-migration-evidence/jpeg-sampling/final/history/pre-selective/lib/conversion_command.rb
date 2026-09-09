class ConversionCommand
  MAX_CONVERT_FORMAT_SECONDS = 20
  def execute_convert(from, to, opts = {}, read: [], write: [])
    command = [from, "-auto-orient", "-background", "white", "-interlace", "none"]
    command << "-flatten" unless opts[:flatten] == false
    command << "-debug" << "all" if opts[:debug]
    command << "-quality" << opts[:quality].to_s if opts[:quality]
    command << to

    ImageMagick.magick(
      *command,
      operation: :upload_format_conversion,
      read:,
      write:,
      failure_message: I18n.t("upload.png_to_jpg_conversion_failure_message"),
      timeout: MAX_CONVERT_FORMAT_SECONDS,
    )
  end

end
