class Admin::EmbeddingController < Admin::AdminController

  before_filter :ensure_logged_in, :ensure_staff, :fetch_embedding

  def show
    render_serialized(@embedding, EmbeddingSerializer, root: 'embedding', rest_serializer: true)
  end

  def update
    render_serialized(@embedding, EmbeddingSerializer, root: 'embedding', rest_serializer: true)
  end

  protected

    def fetch_embedding
      @embedding = OpenStruct.new({
        id: 'default',
        embeddable_hosts: EmbeddableHost.all.order(:host)
      })
    end
end
