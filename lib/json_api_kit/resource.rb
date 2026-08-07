# frozen_string_literal: true

module JsonApiKit
  # What a type exposes, declared in one place: the model behind it, the name it goes out under,
  # the ways its listings may be ordered, and — as they arrive — its attributes, relationships and
  # filters. A resource records its declarations and answers questions about them; reading rows and
  # rendering documents belong to the objects that consult it.
  #
  # Each family of declarations is a concern of its own, so this class is the list of them.
  class Resource
    include Naming
    include Sorting
    include Filtering
    include QueryInterface
  end
end
