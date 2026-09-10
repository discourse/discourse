# frozen_string_literal: true

describe "Edit wireframe cards" do
  include ThemeScreenshotMarker

  fab!(:admin)

  let(:editor) { PageObjects::Pages::WireframeEditor.new }
  let(:cards) { PageObjects::Components::WireframeCards.new }
  let(:image_editor) { PageObjects::Components::WireframeImageEditor.new }
  let(:cdp) { PageObjects::CDP.new }
  let(:dialog) { PageObjects::Components::Dialog.new }

  before do
    SiteSetting.wireframe_enabled = true
    SiteSetting.external_system_avatars_enabled = true
    SiteSetting.external_system_avatars_url =
      "/images/discourse-logo-sketch.png?v={username}&s={size}"
    theme =
      RemoteTheme.import_theme_from_directory(
        File.expand_path("../fixtures/themes/wireframe-card-test-theme", __dir__),
      )
    Theme.find(SiteSetting.default_theme_id).child_themes << theme
    sign_in(admin)
  end

  after { Theme.clear_cache! }

  it "shows all reference Cards without structural issues" do
    visit("/latest")
    editor.enter
    cards.show_issues
    expect(cards).to have_no_issues, cards.issue_messages
  end

  it "lets readers tab to and follow each independent Card link" do
    visit("/latest")
    cards.start_keyboard_navigation
    [
      ["visitor guide", "body"],
      ["Book your visit", "primary"],
      ["Read the transcript", "secondary"],
      ["Explore the collection", "whole"],
    ].each do |label, destination|
      cards.press_tab
      if destination == "whole"
        screenshot_marker(label: "wireframe-card-keyboard-whole", only: :desktop)
      end
      expect(cards).to have_focused_reader_link(label)
      cards.follow_focused_link
      expect(page).to have_current_path("#{page.server_url}/latest#card-#{destination}", url: true)
    end

    cards.click_exhibition_title
    expect(page).to have_current_path("#{page.server_url}/latest#card-primary", url: true)
    cards.click_reader_link("visitor guide")
    expect(page).to have_current_path("#{page.server_url}/latest#card-body", url: true)
    cards.click_reader_link("Read the transcript")
    expect(page).to have_current_path("#{page.server_url}/latest#card-secondary", url: true)
  end

  it "keeps reader Cards within narrow sections without clipping their content" do
    cards.use_narrow_reader
    visit("/latest")
    expect(cards).to have_loaded_artwork
    %w[
      museum-cards
      meta-cards
      hubspot-dark
      hubspot-light
      populii-cards
      meta-below
    ].each do |reference|
      cards.show_reference(reference)
      expect(cards).to have_intact_reader_cards(reference)
      expect(cards).to have_initials_in_identity_color if reference == "meta-cards"
      screenshot_marker(label: "wireframe-card-reader-narrow-#{reference}")
    end
  end

  it "shows the lower static reference Cards in narrow sections" do
    cards.use_narrow_reader
    visit("/latest")
    expect(cards).to have_loaded_artwork
    %w[
      museum-neutrino
      meta-falling-apart
      hubspot-dark-programme
      hubspot-dark-roundtable
      hubspot-light-programme
      hubspot-light-roundtable
      populii-gig
      meta-falling-apart-below
    ].each do |reference|
      cards.show_reference(reference)
      expect(cards).to have_intact_reference_card(reference)
      screenshot_marker(label: "wireframe-card-reader-lower-#{reference}")
    end
  end

  it "keeps Card inspector groups distinct and readable at every rail width" do
    cards.use_wide_editor
    visit("/latest")
    editor.enter
    cards.show_media_stories
    cards.select_speaker

    [240, 300, 520].each do |width|
      editor.resize_inspector(width)
      expect(editor).to have_inspector_width(width)
      cards.show_optional_groups
      expect(cards).to have_readable_group_headings
      expect(cards).to have_distinct_media_sections
      screenshot_marker(label: "wireframe-card-inspector-#{width}", only: :desktop)
    end
  end

  it "shows complete highlight and fully populated Cards without clipping" do
    visit("/latest")
    expect(cards).to have_loaded_artwork
    %w[hubspot-dark-highlight hubspot-light-highlight].each do |reference|
      cards.show_complete_reference(reference)
      expect(cards).to have_complete_reference_in_view(reference)
      screenshot_marker(label: "wf-card-full-#{reference}", only: :desktop, preserve_viewport: true)
    end

    cards.allocate_stress_width(320)
    %w[stress-above stress-below stress-beside stress-behind].each do |reference|
      cards.show_complete_reference(reference)
      expect(cards).to have_complete_reference_in_view(reference)
      expect(cards).to have_intact_reader_cards("card-stress")
      screenshot_marker(label: "wf-card-full-#{reference}", only: :desktop, preserve_viewport: true)
    end
  end

  it "lets readers and authors use Cards with enlarged right-to-left text" do
    cards.use_wide_editor
    visit("/latest")
    expect(cards).to have_loaded_artwork
    cards.enlarge_text(direction: "rtl")
    cards.show_complete_reference("meta-cards")
    expect(cards).to have_enlarged_rtl_text
    expect(cards).to have_intact_reader_cards("meta-cards")
    expect(cards).to have_wrapped_media_stories
    screenshot_marker(label: "wf-card-rtl-reader", only: :desktop, preserve_viewport: true)

    editor.enter
    cards.show_media_stories
    cards.select_speaker
    cards.toggle_identity_group
    cards.fill_identity_name("الدكتورة ليلى عبد الرحمن، باحثة في بناء المجتمعات والتعلم التعاوني")
    cards.toggle_identity_group
    cards.show_complete_reference("meta-cards")
    expect(cards).to have_enlarged_rtl_text
    expect(cards).to have_intact_reader_cards("meta-cards")
    expect(cards).to have_wrapped_media_stories
    expect(cards).to have_no_image_warnings
    screenshot_marker(label: "wf-card-rtl-editor", only: :desktop, preserve_viewport: true)
  end

  it "keeps enlarged Card image controls readable in both text directions" do
    capture = { preserve_viewport: true }
    cards.use_wide_editor
    %w[ltr rtl].each do |direction|
      visit("/latest")
      page.refresh
      cards.enlarge_text(direction: direction)
      editor.enter
      cards.show_media_stories
      cards.select_speaker

      [240, 300, 520].each do |width|
        editor.resize_inspector(width)
        expect(editor).to have_inspector_width(width)
        cards.show_image_controls
        expect(cards).to have_readable_image_controls
        screenshot_marker(label: "wf-card-big-#{direction}-#{width}", only: :desktop, **capture)
      end
    end
  end

  it "shows empty optional Card fields only while that Card is selected" do
    cards.use_wide_editor
    visit("/latest")
    editor.enter
    cards.show_media_stories
    expect(cards).to have_no_optional_story_placeholders
    cards.select_story_without_body
    expect(cards).to have_optional_story_placeholders
    cards.select_speaker
    expect(cards).to have_no_optional_story_placeholders
    screenshot_marker(label: "wireframe-card-selected-placeholders", only: :desktop)
  end

  it "lets the author reload a private Card draft and then publish it to the reader" do
    saved_name = "Sam Saffron, saved speaker"
    cards.use_wide_editor
    visit("/latest")
    editor.enter
    cards.show_media_stories
    cards.select_speaker
    cards.position_speaker_image(:feature, x: 20, y: 80)
    editor.create_customization_component
    dialog.click_yes
    expect(editor).to have_publishable_target
    cards.show_media_stories
    cards.select_speaker
    cards.position_speaker_image(:feature, x: 25, y: 75)
    cards.toggle_identity_group
    cards.fill_identity_name(saved_name)
    cards.position_speaker_image(:portrait, x: 70, y: 30)

    editor.save_draft
    expect(editor).to have_saved_draft
    visit("/latest")
    cards.show_media_stories
    expect(cards).to have_speaker_identity("Sam Saffron")
    expect(cards).to have_no_speaker_identity(saved_name)

    editor.enter
    cards.show_media_stories
    expect(cards).to have_speaker_identity(saved_name)
    expect(cards).to have_speaker_image_position(:feature, x: 25, y: 75)
    expect(cards).to have_speaker_image_position(:portrait, x: 70, y: 30)

    editor.publish
    expect(editor).to have_reader
    page.refresh
    cards.show_media_stories
    expect(cards).to have_speaker_identity(saved_name)
    expect(cards).to have_speaker_image_position(:feature, x: 25, y: 75)
    expect(cards).to have_speaker_image_position(:portrait, x: 70, y: 30)
  end

  it "lets the author reach text over feature images" do
    cards.use_wide_editor
    visit("/latest")
    editor.enter
    cards.show_museum
    cards.select_curator
    expect(cards).to have_selected_curator
    cards.show_media_stories
    cards.select_speaker
    expect(cards).to have_reachable_media_identity
    cards.edit_media_identity
    expect(cards).to have_focused_media_identity
  end

  it "lets the author crop the feature image and portrait independently" do
    cards.use_wide_editor
    visit("/latest")
    editor.enter
    cards.show_media_stories
    cards.select_speaker

    cards.position_speaker_image(:feature, x: 25, y: 75)
    expect(cards).to have_speaker_image_position(:feature, x: 25, y: 75)
    cards.toggle_identity_group
    cards.position_speaker_image(:portrait, x: 70, y: 30)
    expect(cards).to have_speaker_image_position(:portrait, x: 70, y: 30)
    expect(cards).to have_speaker_image_position(:feature, x: 25, y: 75)

    cards.reposition_speaker_image(:portrait)
    expect(image_editor).to have_adjustment
    image_editor.nudge(:right)
    expect(cards).to have_speaker_image_position(:portrait, x: 71, y: 30)
    image_editor.nudge(:escape)
    expect(image_editor).to have_no_adjustment
    expect(cards).to have_focused_reposition(:portrait)
    expect(cards).to have_speaker_image_position(:portrait, x: 70, y: 30)
    expect(cards).to have_speaker_image_position(:feature, x: 25, y: 75)

    cards.reposition_speaker_image(:feature)
    image_editor.nudge(:left)
    image_editor.finish_adjustment
    expect(image_editor).to have_no_adjustment
    expect(cards).to have_speaker_image_position(:feature, x: 24, y: 75)
    image_editor.undo
    expect(cards).to have_speaker_image_position(:feature, x: 25, y: 75)
    expect(cards).to have_speaker_image_position(:portrait, x: 70, y: 30)
  end

  it "lets the author replace four card image sources from closed controls" do
    cards.use_wide_editor
    visit("/latest")
    editor.enter
    cards.show_media_stories
    cards.select_speaker
    cards.toggle_identity_group

    source_files = {
      feature: %w[logo.png logo-dev.png],
      portrait: %w[smallest.png transparent.png],
    }
    source_files.each do |region, (light_file, dark_file)|
      cdp.with_paused_request(%r{/uploads\.json}) do |request|
        cards.drop_speaker_source(file_from_fixtures(light_file, "images").path, region:)
        request.wait
        expect(cards).to have_closed_source_progress(region)
        request.resume
      end
      expect(cards).to have_uploaded_speaker_sources(region, count: 1)
      cards.drop_speaker_source(file_from_fixtures(dark_file, "images").path, region:, dark: true)
      expect(cards).to have_uploaded_speaker_sources(region, count: 2)
    end

    expect(cards).to have_four_distinct_speaker_sources
    sources = cards.speaker_source_urls
    editor.save_draft
    expect(editor).to have_saved_draft
    page.refresh
    editor.enter
    cards.show_media_stories
    cards.select_speaker
    cards.toggle_identity_group
    expect(cards).to have_speaker_sources(sources)
    cards.remove_speaker_feature
    expect(cards).to have_empty_feature_chooser
    expect(cards).to have_feature_prompt_inside_media
    expect(cards).to have_uploaded_speaker_sources(:portrait, count: 2)
    expect(cards).to have_speaker_identity("Sam Saffron")
    screenshot_marker(label: "wireframe-card-empty-feature", only: :desktop)
  end

  it "shows the podcast label with its headphones artwork" do
    visit("/latest")
    cards.show_media_stories
    expect(cards).to have_podcast_icon
  end

  it "keeps the Card row aligned when the author undoes and redoes a longer identity" do
    cards.use_wide_editor
    visit("/latest")
    editor.enter
    cards.show_media_stories
    cards.select_speaker
    expect(cards).to have_aligned_media_stories
    original_height = cards.media_story_height
    cards.toggle_identity_group
    cards.fill_identity_name("Sam Saffron, community researcher and co-founder. " * 20)
    cards.toggle_identity_group
    expect(cards).to have_expanded_media_stories(original_height)
    expect(cards).to have_aligned_media_stories

    image_editor.undo
    expect(cards).to have_speaker_identity("Sam Saffron")
    expect(cards).to have_media_story_height(original_height)
    expect(cards).to have_aligned_media_stories
    image_editor.redo
    expect(cards).to have_expanded_media_stories(original_height)
    expect(cards).to have_aligned_media_stories
  end

  it "keeps readable aligned Cards while artwork is delayed, fails and then recovers" do
    visit("/latest")
    cards.show_media_stories
    expect(cards).to have_loaded_speaker_artwork
    expect(cards).to have_aligned_media_stories
    height = cards.media_story_height
    artwork_url = cards.speaker_artwork_url

    cdp.with_paused_request(artwork_url) do |request|
      cards.reload_reader_without_waiting_for_artwork
      request.wait
      cards.show_media_stories
      expect(cards).to have_pending_speaker_artwork
      expect(cards).to have_speaker_identity("Sam Saffron")
      expect(cards).to have_media_story_height(height)
      expect(cards).to have_aligned_media_stories
      screenshot_marker(label: "wireframe-card-artwork-pending", only: :desktop)
      request.resume
    end
    expect(cards).to have_loaded_speaker_artwork
    expect(cards).to have_media_story_height(height)
    expect(cards).to have_aligned_media_stories

    cards.with_failed_artwork(artwork_url) do
      cards.reload_reader_without_waiting_for_artwork
      cards.show_media_stories
      expect(cards).to have_failed_speaker_artwork
      expect(cards).to have_speaker_identity("Sam Saffron")
      expect(cards).to have_media_story_height(height)
      expect(cards).to have_aligned_media_stories
      screenshot_marker(label: "wireframe-card-artwork-failed", only: :desktop)
    end

    page.refresh
    cards.show_media_stories
    expect(cards).to have_loaded_speaker_artwork
    expect(cards).to have_media_story_height(height)
    expect(cards).to have_aligned_media_stories
  end

  it "lets the author inspect all reference cards and fully populated cards at narrow allocations" do
    cards.use_wide_editor
    visit("/latest")
    expect(cards).to have_reference_cards

    %w[hubspot-dark hubspot-light andela-reference populii-cards meta-below].each do |reference|
      cards.show_reference(reference)
      screenshot_marker(label: "wireframe-card-#{reference}", only: :desktop)
    end

    cards.show_reference("card-stress")
    [220, 320, 480, 800].each do |width|
      cards.allocate_stress_width(width)
      expect(cards).to have_intact_stress_content
      screenshot_marker(label: "wireframe-card-stress-#{width}", only: :desktop)
    end

    editor.enter
    cards.show_reference("card-stress")
    [220, 320, 480, 800].each do |width|
      cards.allocate_stress_width(width)
      expect(cards).to have_intact_stress_content
    end
    expect(cards).to have_no_image_warnings
  end

  it "lets the author compare complete reference Cards before and during editing" do
    capture = { only: :desktop, preserve_viewport: true }
    cards.use_wide_editor
    visit("/latest")
    expect(cards).to have_loaded_artwork

    %w[reader editor].each do |mode|
      editor.enter if mode == "editor"
      %w[
        museum-cards
        meta-cards
        hubspot-dark
        hubspot-light
        populii-cards
        meta-below
      ].each do |reference|
        cards.show_complete_reference(reference)
        expect(cards).to have_complete_reference_in_view(reference)
        screenshot_marker(label: "wf-card-wide-#{mode}-#{reference}", **capture)
      end
    end
  end

  it "lets the author recover a collapsed identity field and preserve it when toggled" do
    cards.use_wide_editor
    visit("/latest")
    editor.enter
    cards.show_media_stories
    cards.select_speaker
    cards.toggle_identity_group
    cards.fill_identity_name("")
    cards.toggle_identity_group

    expect(cards).to have_identity_name_error
    cards.follow_identity_error_with_keyboard
    expect(cards).to have_focused_identity_name

    cards.fill_identity_name("Sam Saffron, speaker")
    cards.toggle_identity_group
    expect(cards).to have_no_identity_name_error
    expect(cards).to have_speaker_identity("Sam Saffron, speaker")

    cards.toggle_identity_group
    cards.toggle_identity
    expect(cards).to have_no_speaker_identity
    cards.toggle_identity
    expect(cards).to have_speaker_identity("Sam Saffron, speaker")
    expect(cards).to have_identity_name("Sam Saffron, speaker")
  end

  it "shows the author editorial cards and aligned media stories before and during editing" do
    visit("/latest")
    expect(cards).to have_loaded_artwork
    cards.show_museum
    expect(cards).to have_filled_editorial_cell, cards.editorial_geometry.inspect
    screenshot_marker(label: "wireframe-card-museum", only: :desktop)

    cards.show_media_stories
    expect(cards).to have_aligned_media_stories
    expect(cards).to have_separated_card_groups
    screenshot_marker(label: "wireframe-card-media", only: :desktop)

    cards.use_wide_editor
    editor.enter
    cards.show_museum
    expect(cards).to have_filled_editorial_cell, cards.editorial_geometry.inspect
    screenshot_marker(label: "wireframe-card-museum-editor", only: :desktop)

    cards.show_media_stories
    expect(cards).to have_aligned_media_stories
    expect(cards).to have_no_image_warnings
    cards.select_speaker
    expect(cards).to have_selected_speaker
    screenshot_marker(label: "wireframe-card-media-editor", only: :desktop)
  end
end
