class PagesSerializer < ApplicationSerializer

  has_many :page, serializer: PageSerializer, embed: :objects

end
