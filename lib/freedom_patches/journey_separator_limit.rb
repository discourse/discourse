# frozen_string_literal: true

if !Gem::Requirement.new("~> 8.1.0").satisfied_by?(ActionPack.gem_version)
  raise "Check whether Rails now recognizes routes in linear time and remove #{__FILE__}"
end

module FreedomPatches
  module JourneySeparatorLimit
    MAX_SEPARATORS = 128
    private_constant :MAX_SEPARATORS

    def recognize(request)
      path = request.path_info

      if path.bytesize > MAX_SEPARATORS
        path = path.b unless path.encoding.ascii_compatible? && path.valid_encoding?
        return if path.count("./?") > MAX_SEPARATORS
      end

      super
    end
  end
end

ActionDispatch::Journey::Router.prepend(FreedomPatches::JourneySeparatorLimit)
