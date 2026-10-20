# frozen_string_literal: true

module ::Hamilton
  class PagesController < ::ApplicationController
    requires_plugin PLUGIN_NAME

    skip_before_action :check_xhr
    skip_before_action :redirect_to_login_if_required, only: %i[docs guide]

    def index
      render html: "", layout: "application"
    end

    def docs
      render_document("README.md")
    end

    def guide
      render_document("doc/hamilton.md")
    end

    private

    def render_document(filename)
      if request.format.json?
        markdown = File.read(Hamilton::Engine.root.join(filename))
        markdown =
          markdown.gsub("(doc/hamilton.md)", "(#{Discourse.base_path}/hamilton/docs/guide)")
        render json: { html: PrettyText.cook(markdown) }
      else
        render html: "", layout: "application"
      end
    end
  end
end
