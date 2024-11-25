# frozen_string_literal: true

class Admin::EmbeddingController < Admin::AdminController
  before_action :fetch_embedding

  def show
    render_serialized(@embedding, EmbeddingSerializer, root: "embedding", rest_serializer: true)
  end

  def update
    Embedding.settings.each { |s| @embedding.public_send("#{s}=", params[:embedding][s]) }

    if @embedding.save
      fetch_embedding
      render_serialized(@embedding, EmbeddingSerializer, root: "embedding", rest_serializer: true)
    else
      render_json_error(@embedding)
    end
  end

  def new
  end

  def edit
  end

  def settings
  end

  def crawler_settings
  end

  protected

  def fetch_embedding
    @embedding = Embedding.find
  end
end
