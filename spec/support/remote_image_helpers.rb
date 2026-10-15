# frozen_string_literal: true

module RemoteImageHelpers
  def stub_image_size(width: nil, height: nil, animated: nil)
    RemoteImage.stubs(:size_and_animated).returns([[width, height], animated])
  end
end
