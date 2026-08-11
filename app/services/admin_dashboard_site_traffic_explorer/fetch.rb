# frozen_string_literal: true

class AdminDashboardSiteTrafficExplorer::Fetch
  include Service::Base

  params do
    attribute :start_date, :date
    attribute :end_date, :date
    attribute :top_url, :string
    attribute :entry_url, :string
    attribute :referrer, :string
    attribute :country, :string
    attribute :network, :string
    attribute :browser, :string
    attribute :ip, :string

    validates :start_date, :end_date, presence: true
  end

  try(ActiveRecord::QueryCanceled, PG::QueryCanceled) { step :load_traffic }

  private

  def load_traffic(params:)
    context[:traffic] = AdminDashboardSiteTrafficExplorer.call(params.to_hash.compact)
  end
end
