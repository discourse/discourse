# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Styleguide Smoke Test", type: :system do
  fab!(:admin)

  before do
    SiteSetting.styleguide_enabled = true
    sign_in(admin)
  end

  it "renders the pages for each component correctly" do
    visit "/styleguide"
    expect(page).to have_css(".styleguide-contents h1.section-title", text: "Styleguide")

    # first visit the styleguide index page to get a list of all the components
    items = []
    page
      .all(".styleguide-menu > ul")
      .each do |section_node|
        section = section_node.find(".styleguide-heading").text.strip
        anchors = section_node.all("li a")

        anchors.each do |anchor|
          items << { section: section, item: anchor.text.strip, href: anchor[:href] }
        end
      end

    # then visit each component page and check that it renders correctly
    aggregate_failures "Smoke test errors" do
      items.each do |item|
        visit item[:href]

        errors =
          page
            .driver
            .browser
            .logs
            .get(:browser)
            .select { |log| log.level == "SEVERE" }
            .reject do |error|
              error.message.include?("Failed to load resource") ||
                error.message.include?("Manifest")
            end

        if errors.present?
          errors.each do |error|
            expect(error.message).to be_nil,
            "smoke test failed on #{item[:section]}: #{item[:item]} with error: #{error.message}"
          end
        end

        expect(page).to have_css(".styleguide-contents h1.section-title", text: item[:title])
      end
    end
  end
end
