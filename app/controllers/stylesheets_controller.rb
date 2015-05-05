class StylesheetsController < ApplicationController
  skip_before_filter :preload_json, :redirect_to_login_if_required, :check_xhr, :verify_authenticity_token, only: [:show]

  def show

    target,digest = params[:name].split("_")

    digest_orig = digest
    digest = "_" + digest if digest

    # Security note, safe due to route constraint
    location = "#{Rails.root}/#{DiscourseStylesheets::CACHE_PATH}/#{target}#{digest}.css"

    unless File.exist?(location)
      query = StylesheetCache.where(target: target)
      if digest
        query = query.where(digest: digest_orig)
      else
        query = query.order('id desc')
      end

      if current = query.first
        File.write(location, current.content)
      else
        return render nothing: true, status: 404
      end
    end

    expires_in 1.year, public: true unless Rails.env == "development"
    send_file(location, disposition: :inline)

  end
end

