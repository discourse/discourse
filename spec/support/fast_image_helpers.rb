# frozen_string_literal: true

module FastImageHelpers
  def stub_image_size(width: nil, height: nil)
    FastImage.stubs(:size).returns([width, height])
  end
end
