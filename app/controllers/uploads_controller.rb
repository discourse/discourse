class UploadsController < ApplicationController
  before_filter :ensure_logged_in, except: [:show]
  skip_before_filter :check_xhr, only: [:show]

  def create
    file = params[:file] || params[:files].first

    filesize = File.size(file.tempfile)
    upload = Upload.create_for(current_user.id, file.tempfile, file.original_filename, filesize, { content_type: file.content_type })

    if upload.errors.empty?
      render_serialized(upload, UploadSerializer, root: false)
    else
      render status: 422, text: upload.errors.full_messages
    end
  end

  def show
    return render_404 if !RailsMultisite::ConnectionManagement.has_db?(params[:site])

    RailsMultisite::ConnectionManagement.with_connection(params[:site]) do |db|
      return render_404 unless Discourse.store.internal?

      id = params[:id].to_i
      url = request.fullpath

      # the "url" parameter is here to prevent people from scanning the uploads using the id
      if upload = Upload.find_by(id: id, url: url)
        send_file(Discourse.store.path_for(upload), filename: upload.original_filename)
      else
        render_404
      end
    end
  end

  protected

  def render_404
    render nothing: true, status: 404
  end

end
