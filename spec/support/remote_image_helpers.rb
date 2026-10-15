# frozen_string_literal: true

module RemoteImageHelpers
  def stub_image_size(width: nil, height: nil)
    RemoteImage.stubs(:size_and_animated).returns([[width, height], nil])
  end
end
