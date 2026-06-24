# frozen_string_literal: true

describe "Composer - ProseMirror - Event Editor" do
  include_context "with prosemirror editor"

  before do
    SiteSetting.calendar_enabled = true
    SiteSetting.discourse_post_event_enabled = true
    SiteSetting.rich_editor = true
  end

  describe "event rendering" do
    it "renders event node with basic attributes" do
      open_composer
      composer.toggle_rich_editor
      composer.fill_content(
        "[event name=\"Team Meeting\" location=\"Conference Room\" maxAttendees=\"50\" start=\"2025-03-21 15:41\" status=\"public\" timezone=\"Europe/Paris\"]\n[/event]",
      )
      composer.toggle_rich_editor

      expect(rich).to have_css(".composer-event-node")
      expect(rich).to have_css(".composer-event__status", text: "Public")
      expect(rich.find(".composer-event__name-input").value).to eq("Team Meeting")
      expect(rich.find(".composer-event__location-input").value).to eq("Conference Room")
      expect(rich.find(".composer-event__max-attendees-input").value).to eq("50")
    end

    it "displays formatted dates correctly" do
      open_composer
      composer.toggle_rich_editor
      composer.fill_content(
        "[event start=\"2024-12-20T14:00:00Z\" end=\"2024-12-20T16:00:00Z\" status=\"public\" timezone=\"Europe/Paris\"]\n[/event]",
      )
      composer.toggle_rich_editor

      expect(rich).to have_css(".composer-event__month", text: "DEC")
      expect(rich).to have_css(".composer-event__day", text: "20")
      expect(rich).to have_css(".composer-event__date-input")
    end
  end

  describe "field interactions" do
    it "shows placeholders and handles external link detection" do
      open_composer
      composer.toggle_rich_editor
      composer.fill_content(
        "[event start=\"2025-03-21 15:41\" status=\"public\" timezone=\"Europe/Paris\"]\n[/event]",
      )
      composer.toggle_rich_editor

      location_input = rich.find(".composer-event__location-input")
      expect(location_input["placeholder"]).to include("location")

      # Test URL detection
      location_input.fill_in(with: "https://zoom.us/meeting")
      expect(rich).to have_css(".composer-event__location-external-link")

      # Test regular location
      location_input.fill_in(with: "Conference Room A")
      expect(rich).to have_no_css(".composer-event__location-external-link")
    end

    it "loads all field values correctly from markdown" do
      open_composer
      composer.toggle_rich_editor
      composer.fill_content(
        "[event name=\"Team Standup\" location=\"https://meet.google.com/abc-defg-hij\" maxAttendees=\"15\" start=\"2024-12-20T14:00:00Z\" end=\"2024-12-20T16:00:00Z\" status=\"private\" timezone=\"Europe/Paris\"]\nDaily standup meeting\n[/event]",
      )
      composer.toggle_rich_editor

      # Verify all field values are loaded correctly
      expect(rich.find(".composer-event__name-input").value).to eq("Team Standup")
      expect(rich.find(".composer-event__location-input").value).to eq(
        "https://meet.google.com/abc-defg-hij",
      )
      expect(rich.find(".composer-event__max-attendees-input").value).to eq("15")
      expect(rich.find(".composer-event__description-textarea").value).to eq(
        "Daily standup meeting",
      )
      expect(rich).to have_css(".composer-event__status", text: "Private")
      expect(rich).to have_css(".composer-event__location-external-link")

      # Verify date inputs have values
      date_inputs = rich.all(".composer-event__date-input")
      expect(date_inputs.first.value).not_to be_empty
      expect(date_inputs.last.value).not_to be_empty
    end

    it "allows editing name field and persists to markdown" do
      open_composer
      composer.toggle_rich_editor
      composer.fill_content(
        "[event name=\"Original Name\" start=\"2025-03-21 15:41\" status=\"public\" timezone=\"Europe/Paris\"]\n[/event]",
      )
      composer.toggle_rich_editor

      rich.find(".composer-event__name-input").fill_in(with: "Updated Meeting Name")

      composer.toggle_rich_editor
      markdown_content = find(".d-editor-input").value
      expect(markdown_content).to include("Updated Meeting Name")
    end

    it "allows editing location field and persists to markdown" do
      open_composer
      composer.toggle_rich_editor
      composer.fill_content(
        "[event location=\"Old Room\" start=\"2025-03-21 15:41\" status=\"public\" timezone=\"Europe/Paris\"]\n[/event]",
      )
      composer.toggle_rich_editor

      rich.find(".composer-event__location-input").fill_in(with: "New Conference Room")

      composer.toggle_rich_editor
      markdown_content = find(".d-editor-input").value
      expect(markdown_content).to include("New Conference Room")
    end

    it "allows editing description field and persists to markdown" do
      open_composer
      composer.toggle_rich_editor
      composer.fill_content(
        "[event start=\"2025-03-21 15:41\" status=\"public\" timezone=\"Europe/Paris\"]\nOld description content\n[/event]",
      )
      composer.toggle_rich_editor

      rich.find(".composer-event__description-textarea").fill_in(with: "New description content")

      composer.toggle_rich_editor
      markdown_content = find(".d-editor-input").value
      expect(markdown_content).to include("New description content")
    end

    it "allows editing max attendees field and persists to markdown" do
      open_composer
      composer.toggle_rich_editor
      composer.fill_content(
        "[event maxAttendees=\"10\" start=\"2025-03-21 15:41\" status=\"public\" timezone=\"Europe/Paris\"]\n[/event]",
      )
      composer.toggle_rich_editor

      rich.find(".composer-event__max-attendees-input").fill_in(with: "25")

      composer.toggle_rich_editor
      markdown_content = find(".d-editor-input").value
      expect(markdown_content).to include("maxAttendees=25")
    end

    it "allows editing event dates and persists to markdown" do
      open_composer
      composer.toggle_rich_editor
      composer.fill_content(
        "[event start=\"2025-03-21 15:41\" status=\"public\" timezone=\"Europe/Paris\"]\n[/event]",
      )
      composer.toggle_rich_editor

      date_inputs = rich.all(".composer-event__date-input")
      time_inputs = rich.all(".composer-event__time-input")
      date_inputs.first.fill_in(with: "2024-12-20")
      time_inputs.first.fill_in(with: "14:00")
      date_inputs.last.fill_in(with: "2024-12-20")
      time_inputs.last.fill_in(with: "16:00")

      composer.toggle_rich_editor
      markdown_content = find(".d-editor-input").value
      expect(markdown_content).to include("2024-12-20 14:00")
      expect(markdown_content).to include("2024-12-20 16:00")
    end
  end

  describe "validation" do
    it "validates max attendees input" do
      open_composer
      composer.toggle_rich_editor
      composer.fill_content(
        "[event start=\"2025-03-21 15:41\" status=\"public\" timezone=\"Europe/Paris\"]\n[/event]",
      )
      composer.toggle_rich_editor

      max_attendees_input = rich.find(".composer-event__max-attendees-input")

      # Valid input
      max_attendees_input.fill_in(with: "25")
      expect(max_attendees_input.value).to eq("25")

      # Negative input gets cleared
      max_attendees_input.fill_in(with: "-10")
      expect(max_attendees_input.value).to eq("")

      # Typing 0 disables attendance
      max_attendees_input.fill_in(with: "0")
      max_attendees_input.send_keys(:tab)
      expect(rich).to have_css(
        ".composer-event__max-attendees-display",
        text: I18n.t("js.discourse_post_event.composer.no_rsvps_label"),
      )
    end

    it "requires start date for event rendering" do
      open_composer
      composer.toggle_rich_editor
      composer.fill_content("[event start=\"2025-03-21 15:41\" timezone=\"UTC\"]\n[/event]")
      composer.toggle_rich_editor

      expect(rich).to have_css(".composer-event-node")
      expect(rich.find(".composer-event__name-input").value).to be_empty

      # Test that events without start date don't render
      composer.toggle_rich_editor
      composer.fill_content("[event]\n[/event]")
      composer.toggle_rich_editor
      expect(rich).to have_no_css(".composer-event-node")
    end
  end

  describe "advanced features" do
    it "handles fully populated event with all features" do
      open_composer
      composer.toggle_rich_editor
      composer.fill_content(
        "[event name=\"Team Meeting\" location=\"Conference Room A\" maxAttendees=\"25\" start=\"2024-12-20T14:00:00Z\" end=\"2024-12-20T16:00:00Z\" status=\"private\" timezone=\"Europe/Paris\"]\nDetailed meeting description\n[/event]",
      )
      composer.toggle_rich_editor

      expect(rich.find(".composer-event__name-input").value).to eq("Team Meeting")
      expect(rich.find(".composer-event__location-input").value).to eq("Conference Room A")
      expect(rich.find(".composer-event__max-attendees-input").value).to eq("25")
      expect(rich.find(".composer-event__description-textarea").value).to eq(
        "Detailed meeting description",
      )
      expect(rich).to have_css(".composer-event__status", text: "Private")
    end

    it "handles special characters and long values" do
      long_name = "A" * 100
      special_location = "Room #1 @ Building Main"

      open_composer
      composer.toggle_rich_editor
      composer.fill_content(
        "[event name=\"#{long_name}\" location=\"#{special_location}\" start=\"2025-03-21 15:41\" status=\"public\" timezone=\"Europe/Paris\"]\n[/event]",
      )
      composer.toggle_rich_editor

      expect(rich).to have_css(".composer-event-node")
      expect(rich.find(".composer-event__name-input").value).to eq(long_name)
      expect(rich.find(".composer-event__location-input").value).to eq(special_location)
    end

    it "integrates with event builder modal" do
      open_composer
      composer.toggle_rich_editor
      composer.fill_content(
        "[event name=\"Meeting\" start=\"2025-03-21 15:41\" status=\"public\" timezone=\"Europe/Paris\"]\n[/event]",
      )
      composer.toggle_rich_editor

      expect(rich).to have_css(".composer-event__more-dropdown")
    end

    it "persists allowed custom fields edited through the event builder to markdown" do
      SiteSetting.discourse_post_event_allowed_custom_fields = "fancy_field"

      open_composer
      composer.toggle_rich_editor
      composer.fill_content(
        "[event start=\"2025-03-21 15:41\" status=\"public\" timezone=\"Europe/Paris\"]\n[/event]",
      )
      composer.toggle_rich_editor

      rich.find(".composer-event__more-dropdown button").click

      form = PageObjects::Components::FormKit.new(".post-event-builder-modal form")
      form.field("customFields.fancy_field").fill_in("hello world")
      find(".post-event-builder-modal .d-modal__footer .btn-primary").click
      expect(page).to have_no_css(".post-event-builder-modal")

      composer.toggle_rich_editor
      expect(find(".d-editor-input").value).to include("fancyField=\"hello world\"")
    end
  end
end
