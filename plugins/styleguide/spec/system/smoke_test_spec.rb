# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Styleguide Smoke Test", type: :system do
  fab!(:admin)

  # keep this hash updated when adding, removing or renaming components
  sections = {
    "SYNTAX" => [{ href: "/syntax/bem", title: "BEM" }],
    "ATOMS" => [
      { href: "/atoms/typography", title: "Typography" },
      { href: "/atoms/font-scale", title: "Font System" },
      { href: "/atoms/buttons", title: "Buttons" },
      { href: "/atoms/colors", title: "Colors" },
      { href: "/atoms/icons", title: "Icons" },
      { href: "/atoms/forms", title: "Forms" },
      { href: "/atoms/spinners", title: "Spinners" },
      { href: "/atoms/date-time-inputs", title: "Date/Time inputs" },
      { href: "/atoms/dropdowns", title: "Dropdowns" },
      { href: "/atoms/topic-link", title: "Topic Link" },
      { href: "/atoms/topic-statuses", title: "Topic Statuses" },
    ],
    "MOLECULES" => [
      { href: "/molecules/bread-crumbs", title: "Bread Crumbs" },
      { href: "/molecules/categories", title: "Categories" },
      { href: "/molecules/char-counter", title: "Character Counter" },
      { href: "/molecules/empty-state", title: "Empty State" },
      { href: "/molecules/footer-message", title: "Footer Message" },
      { href: "/molecules/menus", title: "Menus" },
      { href: "/molecules/navigation-bar", title: "Navigation Bar" },
      { href: "/molecules/navigation-stacked", title: "Navigation Stacked" },
      { href: "/molecules/post-menu", title: "Post Menu" },
      { href: "/molecules/signup-cta", title: "Signup CTA" },
      { href: "/molecules/toasts", title: "Toasts" },
      { href: "/molecules/tooltips", title: "Tooltips" },
      { href: "/molecules/topic-list-item", title: "Topic List Item" },
      { href: "/molecules/topic-notifications", title: "Topic Notifications" },
      { href: "/molecules/topic-timer-info", title: "Topic Timers" },
    ],
    "ORGANISMS" => [
      { href: "/organisms/post", title: "Post" },
      { href: "/organisms/topic-map", title: "Topic Map" },
      { href: "/organisms/topic-footer-buttons", title: "Topic Footer Buttons" },
      { href: "/organisms/topic-list", title: "Topic List" },
      { href: "/organisms/basic-topic-list", title: "Basic Topic List" },
      { href: "/organisms/categories-list", title: "Categories List" },
      { href: "/organisms/chat", title: "Chat" },
      { href: "/organisms/modal", title: "Modal" },
      { href: "/organisms/navigation", title: "Navigation" },
      { href: "/organisms/site-header", title: "Site Header" },
      { href: "/organisms/suggested-topics", title: "Suggested Topics" },
      { href: "/organisms/user-about", title: "User About Box" },
    ],
  }

  before do
    SiteSetting.styleguide_enabled = true
    sign_in(admin)
  end

  # this test will check if the index page is rendering correctly and also ensures that all component pages are
  # declared in the sections hash above
  it "renders the index page correctly and collect information about the available page" do
    visit "/styleguide"
    expect(page).to have_css(".styleguide-contents h1.section-title", text: "Styleguide")

    existing_sections = {}
    page
      .all(".styleguide-menu > ul")
      .each do |section_node|
        section = section_node.find(".styleguide-heading").text.strip

        existing_sections[section] ||= []
        items = existing_sections[section]

        anchors = section_node.all("li a")
        anchors.each { |anchor| items << { title: anchor.text.strip, href: anchor[:href] } }
      end

    expect(existing_sections.keys).to match_array(sections.keys)

    sections.each do |section, items|
      items.each do |item|
        existing_items = existing_sections[section]
        existing_item = existing_items.find { |i| i[:title] == item[:title] }

        expect(existing_item).not_to be_nil,
        "Item #{item[:title]} not declared in section #{section}"
        expect(existing_item[:href]).to end_with(item[:href])

        expect(existing_items.size).to eq(items.size),
        "Section #{section} has a different number of items declared then what was found in the index page"
      end
    end
  end

  # uses the sections hash to generate a test for each page and check if it renders correctly
  context "when testing the available pages" do
    before do
      SiteSetting.styleguide_enabled = true
      sign_in(admin)
    end

    sections.each do |section, items|
      items.each do |item|
        it "renders the #{section}: #{item[:title]} page correctly" do
          visit "/styleguide/#{item[:href]}"

          errors =
            page
              .driver
              .browser
              .logs
              .get(:browser)
              .select { |log| log.level == "SEVERE" }
              .reject do |error|
                ["Failed to load resource", "Manifest", "PresenceChannelNotFound"].any? do |msg|
                  error.message.include?(msg)
                end
              end

          if errors.present?
            errors.each do |error|
              expect(error.message).to be_nil, "smoke test failed with error: #{error.message}"
            end
          end

          expect(page).to have_css(".styleguide-contents h1.section-title", text: item[:title])
        end
      end
    end
  end
end
