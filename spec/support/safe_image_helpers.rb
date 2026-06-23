# frozen_string_literal: true

module SafeImageHelpers
  def stub_image_size(width: nil, height: nil)
    SafeImage.stubs(:remote_size).returns([width, height])
  end
end
