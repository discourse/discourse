# frozen_string_literal: true

# Where the bundle analyzer dev tool finds the reports the builds left behind.
# One per plugin, since each plugin compiles on its own, plus core's.
class BundleAnalysisController < ApplicationController
  skip_before_action :preload_json, :check_xhr

  def index
    enabled = Discourse.plugins.select(&:enabled?).map(&:directory_name).to_set
    reports =
      Plugin::JsManager.bundle_analysis_assets.filter_map do |name, path|
        path if enabled.include?(name)
      end

    render json: {
             core: report_url(EmberAssets.bundle_analysis_asset),
             plugins: reports.map { report_url(it) },
           }
  end

  private

  def report_url(logical_path)
    view_context.asset_cdn_path(logical_path, brotli: true) if logical_path
  end
end
