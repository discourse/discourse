# frozen_string_literal: true

RSpec.describe Jobs::BackfillSidebarSiteSettings do
  it "has a cluster concurrency of 1" do
    expect(Jobs::BackfillSidebarSiteSettings.get_cluster_concurrency).to eq(1)
  end
end
