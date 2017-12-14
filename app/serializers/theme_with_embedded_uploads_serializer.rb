class ThemeWithEmbeddedUploadsSerializer < ThemeSerializer
  has_many :theme_fields, serializer: ThemeFieldWithEmbeddedUploadsSerializer, embed: :objects
end
