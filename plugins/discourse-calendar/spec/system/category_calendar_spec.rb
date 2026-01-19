# frozen_string_literal: true

describe "Category calendar", type: :system do
  fab!(:admin)
  fab!(:user)
  fab!(:category)

  let(:category_page) { PageObjects::Pages::Category.new }

  context "with events_calendar_categories" do
    before do
      SiteSetting.calendar_enabled = true
      SiteSetting.discourse_post_event_enabled = true
      SiteSetting.events_calendar_categories = category.id.to_s

      PostCreator.create!(
        admin,
        title: "Sell a boat party",
        category: category.id,
        raw: "[event start=\"#{Time.now.iso8601}\"]\n[/event]",
      )

      sign_in(admin)
    end

    it "shows the calendar on the category page" do
      category_page.visit(category)

      expect(category_page).to have_selector(
        "#category-events-calendar.--discovery-list-container-top .fc",
      )
      expect(category_page).to have_css(
        ".fc-daygrid-event-harness .fc-event-title",
        text: "Sell a boat party",
      )

      find(".nav-item_hot").click

      expect(page).to have_current_path("#{category.relative_url}/l/hot")
      expect(category_page).to have_selector("#category-events-calendar .fc")

      find(".nav-item_latest").click

      expect(page).to have_current_path("#{category.relative_url}/l/latest")
      expect(category_page).to have_selector("#category-events-calendar .fc")
    end

    context "when discourse_post_event_enabled is false" do
      before { SiteSetting.discourse_post_event_enabled = false }

      it "does not crash the page" do
        category_page.visit(category)

        expect(category_page).to have_no_selector("#category-events-calendar .fc")
        expect(category_page).to have_content("Sell a boat party")
      end
    end
  end

  context "with calendar_categories" do
    before do
      SiteSetting.calendar_enabled = true
      SiteSetting.discourse_post_event_enabled = true
      # postId should be irrelevant now, it's a legacy property
      SiteSetting.calendar_categories = "categoryId=#{category.id};postId=2313"

      PostCreator.create!(
        admin,
        title: "Sell a boat party",
        category: category.id,
        raw: "[event start=\"#{Time.now.iso8601}\"]\n[/event]",
      )

      sign_in(admin)
    end

    it "shows the calendar on the category page" do
      category_page.visit(category)

      expect(category_page).to have_selector(
        "#category-events-calendar.--discovery-list-container-top .fc",
      )
      expect(category_page).to have_css(
        ".fc-daygrid-event-harness .fc-event-title",
        text: "Sell a boat party",
      )

      find(".nav-item_hot").click

      expect(page).to have_current_path("#{category.relative_url}/l/hot")
      expect(category_page).to have_selector("#category-events-calendar .fc")

      find(".nav-item_latest").click

      expect(page).to have_current_path("#{category.relative_url}/l/latest")
      expect(category_page).to have_selector("#category-events-calendar .fc")
    end
  end

  context "with color mapping" do
    before do
      SiteSetting.calendar_enabled = true
      SiteSetting.discourse_post_event_enabled = true
      sign_in(user)
    end

    context "with tag color" do
      fab!(:tag) { Fabricate(:tag, name: "awesome-tag") }

      before do
        SiteSetting.events_calendar_categories = category.id.to_s
        SiteSetting.map_events_to_color = [
          { type: "tag", color: "rgb(231, 76, 60)", slug: "awesome-tag" },
        ].to_json
      end

      it "displays the event with the correct color" do
        create_post(
          user: admin,
          topic: Fabricate(:topic, category: category, tags: [tag]),
          raw: "[event start=\"#{Time.now.iso8601}\"]\n[/event]",
        )

        category_page.visit(category)

        expect(category_page).to have_css(".fc-daygrid-event-harness")
        expect(get_rgb_color(find(".fc-daygrid-event-dot"), "borderColor")).to eq(
          "rgb(231, 76, 60)",
        )
      end
    end

    context "with category color" do
      fab!(:category_for_color) { Fabricate(:category, slug: "colored-category") }

      before do
        SiteSetting.events_calendar_categories = category_for_color.id.to_s
        SiteSetting.map_events_to_color = [
          { type: "category", color: "rgb(46, 204, 113)", slug: "colored-category" },
        ].to_json
      end

      it "displays the event with the correct color" do
        create_post(
          user: admin,
          category: category_for_color,
          raw: "[event start=\"#{Time.now.iso8601}\"]\n[/event]",
        )

        category_page.visit(category_for_color)

        expect(category_page).to have_css(".fc-daygrid-event-harness")
        expect(get_rgb_color(find(".fc-daygrid-event-dot"), "borderColor")).to eq(
          "rgb(46, 204, 113)",
        )
      end
    end
  end
end
