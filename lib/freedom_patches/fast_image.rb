# frozen_string_literal: true

# Remove when https://github.com/sdsykes/fastimage/pull/115
# has been merged. Please remove the specs as well.
class FastImage
  attr_reader :original_type

  private

  old_parse_type = instance_method(:parse_type)

  define_method(:parse_type) do
    @original_type = old_parse_type.bind(self).()

    if @original_type == :svg && @stream.peek(2) == "<s"
      raise UnknownImageType if @stream.peek(4) != "<svg"
    end

    @original_type
  end
end
