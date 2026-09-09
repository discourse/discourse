require "ffi"

module DiscourseVips
  class IcoImage
    module Native
      extend FFI::Library

      ffi_lib ["gdk_pixbuf-2.0", "libgdk_pixbuf-2.0.so.0"]

      attach_function :gdk_pixbuf_loader_new_with_type, [:string, :pointer], :pointer
      attach_function :gdk_pixbuf_loader_write, [:pointer, :pointer, :size_t, :pointer], :int
      attach_function :gdk_pixbuf_loader_close, [:pointer, :pointer], :int
      attach_function :gdk_pixbuf_loader_get_pixbuf, [:pointer], :pointer
      attach_function :gdk_pixbuf_get_width, [:pointer], :int
      attach_function :gdk_pixbuf_get_height, [:pointer], :int
      attach_function :gdk_pixbuf_get_n_channels, [:pointer], :int
      attach_function :gdk_pixbuf_get_rowstride, [:pointer], :int
      attach_function :gdk_pixbuf_get_bits_per_sample, [:pointer], :int
      attach_function :gdk_pixbuf_get_byte_length, [:pointer], :size_t
      attach_function :gdk_pixbuf_get_pixels, [:pointer], :pointer
      attach_function :g_object_unref, [:pointer], :void
      attach_function :g_error_free, [:pointer], :void

      class Error < FFI::Struct
        layout :domain, :uint, :code, :int, :message, :pointer
      end
    end
    private_constant :Native

    def self.load(input_path)
      File.open(input_path, "rb") do |file|
        header = file.read(6)
        raise ArgumentError, "invalid ICO header" if header&.bytesize != 6

        reserved, type, count = header.unpack("v3")
        if reserved != 0 || type != 1 || count.zero? || file.size < 6 + count * 16
          raise ArgumentError, "invalid ICO directory"
        end

        file.seek(6 + (count - 1) * 16)
        entry = file.read(16)
        size_bytes, offset_bytes = entry.byteslice(8, 8).unpack("V2")
        if size_bytes.zero? || offset_bytes < 6 + count * 16 ||
             offset_bytes + size_bytes > file.size
          raise ArgumentError, "invalid ICO image offset"
        end

        file.seek(offset_bytes)
        payload = file.read(size_bytes)
        if payload.start_with?("\x89PNG\r\n\x1A\n".b)
          Vips::Image.pngload_buffer(payload)
        else
          single_image = [0, 1, 1].pack("v3") + entry.byteslice(0, 12) + [22].pack("V") + payload
          image = load_bitmap(single_image)
          if payload.byteslice(14, 2).unpack1("v") == 1
            colors = payload.byteslice(40, 8).unpack("C8").each_slice(4).map { |color| color.first(3).reverse }
            pixels = image[0].ifthenelse(colors[1], colors[0]).cast(:uchar)
            image = image.has_alpha? ? pixels.bandjoin(image[3]) : pixels
          end
          image
        end
      end
    end

    def self.load_bitmap(ico_data)
      error = FFI::MemoryPointer.new(:pointer)
      loader = Native.gdk_pixbuf_loader_new_with_type("ico", error)
      close_attempted = false

      if !loader.null?
        buffer = FFI::MemoryPointer.from_string(ico_data)
        if Native.gdk_pixbuf_loader_write(loader, buffer, ico_data.bytesize, error) != 0
          close_attempted = true
          decoded = Native.gdk_pixbuf_loader_close(loader, error) != 0
        end
      end

      if !decoded
        message =
          if error.read_pointer.null?
            "unable to decode ICO image"
          else
            Native::Error.new(error.read_pointer)[:message].read_string
          end
        raise ArgumentError, message
      end

      pixbuf = Native.gdk_pixbuf_loader_get_pixbuf(loader)
      raise ArgumentError, "ICO image has no pixels" if pixbuf.null?

      width = Native.gdk_pixbuf_get_width(pixbuf)
      height = Native.gdk_pixbuf_get_height(pixbuf)
      channels = Native.gdk_pixbuf_get_n_channels(pixbuf)
      rowstride = Native.gdk_pixbuf_get_rowstride(pixbuf)
      if Native.gdk_pixbuf_get_bits_per_sample(pixbuf) != 8 || ![3, 4].include?(channels)
        raise ArgumentError, "unsupported ICO pixel format"
      end
      if width <= 0 || height <= 0 || rowstride < width * channels ||
           (height - 1) * rowstride + width * channels > Native.gdk_pixbuf_get_byte_length(pixbuf)
        raise ArgumentError, "invalid ICO pixel layout"
      end

      pixels = Native.gdk_pixbuf_get_pixels(pixbuf)
      raise ArgumentError, "ICO image has no pixels" if pixels.null?

      pixel_data = Array.new(height) { |row| pixels.get_bytes(row * rowstride, width * channels) }.join
      Vips::Image.new_from_memory(pixel_data, width, height, channels, :uchar).copy(interpretation: :srgb)
    ensure
      if loader && !loader.null?
        Native.gdk_pixbuf_loader_close(loader, nil) if !close_attempted
        Native.g_object_unref(loader)
      end
      Native.g_error_free(error.read_pointer) if error && !error.read_pointer.null?
    end
    private_class_method :load_bitmap
  end
end
