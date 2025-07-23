# frozen_string_literal: true

require "rails_helper"
require_dependency "site"

describe Site do
  let(:category) { Fabricate(:category) }
  let(:guardian) { Guardian.new }

  before { SiteSetting.show_filter_by_solved_status = true }

  it "includes `enable_accepted_answers` custom field for categories" do
    category.custom_fields["enable_accepted_answers"] = true
    category.save_custom_fields

    json = Site.json_for(guardian)

    expect(json).to include("enable_accepted_answers")
  end
end
