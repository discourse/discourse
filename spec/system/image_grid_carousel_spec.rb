# frozen_string_literal: true

describe "Image Carousel" do
  fab!(:current_user, :admin)
  fab!(:upload1) do
    UploadCreator.new(file_from_fixtures("logo.png", "images"), "logo.png").create_for(
      current_user.id,
    )
  end
  fab!(:upload2) do
    UploadCreator.new(file_from_fixtures("logo.jpg", "images"), "logo.jpg").create_for(
      current_user.id,
    )
  end

  let(:composer) { PageObjects::Components::Composer.new }
  let(:topic_page) { PageObjects::Pages::Topic.new }

  before { sign_in(current_user) }

  it "renders a carousel in the post stream" do
    post = create_post(raw: <<~MD)
      [grid mode=carousel]
      ![logo|100x100](#{upload1.short_url})
      ![logo|100x100](#{upload2.short_url})
      [/grid]
    MD

    topic_page.visit_topic(post.topic, post_number: post.post_number)
    carousel = PageObjects::Components::ImageCarousel.new(post.post_number)

    expect(carousel).to have_carousel
    expect(carousel).to have_mode("carousel")
    expect(carousel).to have_track
    expect(carousel).to have_slides(count: 2)
  end

  it "wraps around in carousel mode" do
    post = create_post(raw: <<~MD)
      [grid mode=carousel]
      ![logo|100x100](#{upload1.short_url})
      ![logo|100x100](#{upload2.short_url})
      [/grid]
    MD

    topic_page.visit_topic(post.topic, post_number: post.post_number)
    carousel = PageObjects::Components::ImageCarousel.new(post.post_number)

    expect(carousel).to have_active_slide_index(0)

    carousel.click_prev
    expect(carousel).to have_active_slide_index(1)

    carousel.click_next
    expect(carousel).to have_active_slide_index(0)

    carousel.click_next
    expect(carousel).to have_active_slide_index(1)

    carousel.click_next
    expect(carousel).to have_active_slide_index(0)
  end

  it "keyboard navigation wraps around in carousel mode" do
    post = create_post(raw: <<~MD)
      [grid mode=carousel]
      ![logo|100x100](#{upload1.short_url})
      ![logo|100x100](#{upload2.short_url})
      [/grid]
    MD

    topic_page.visit_topic(post.topic, post_number: post.post_number)
    carousel = PageObjects::Components::ImageCarousel.new(post.post_number)

    carousel.focus_track

    send_keys(:left)
    expect(carousel).to have_active_slide_index(1)

    wait_for_timeout(150) # we throttle keyboard actions

    send_keys(:right)
    expect(carousel).to have_active_slide_index(0)
  end

  it "allows changing modes in the rich text editor", js: true do
    SiteSetting.post_menu_hidden_items = ""
    current_user.user_option.update!(composition_mode: UserOption.composition_mode_types[:rich])

    post = create_post(raw: <<~MD)
      [grid mode=carousel]
      ![logo|100x100](#{upload1.short_url})
      [/grid]
    MD

    topic_page.visit_topic(post.topic, post_number: post.post_number)
    expect(topic_page).to have_post_action_button(post, :edit)
    topic_page.click_post_action_button(post, :edit)

    expect(composer).to be_opened
    expect(composer).to have_rich_editor_active
    expect(composer.image_grid).to have_mode_select

    composer.image_grid.select_mode("Grid")
    expect(composer.image_grid).to have_selected_mode("grid")

    composer.toggle_rich_editor
    expect(composer.composer_input.value).to include("[grid]")
  end

  it "keeps controls usable for short, tall, and multiple grids", js: true do
    SiteSetting.post_menu_hidden_items = ""
    current_user.user_option.update!(composition_mode: UserOption.composition_mode_types[:rich])
    blocks = Array.new(60, "<br>").join("\n\n")
    post = create_post(raw: "[grid]\n<br>\n[/grid]\n\n[grid]\n#{blocks}\n[/grid]")

    topic_page.visit_topic(post.topic, post_number: post.post_number)
    topic_page.click_post_action_button(post, :edit)

    expect(composer).to be_opened
    expect(composer).to have_rich_editor_active
    expect(composer.image_grid).to have_grids(count: 2)
    expect(composer.image_grid).to have_mode_selects(count: 2)

    wait_for do
      empty_grid_positions = composer.image_grid.control_positions(index: 0)
      empty_grid_positions["modeBottom"] < empty_grid_positions["removeTop"] &&
        empty_grid_positions["removeLabelLineCount"] == 1 &&
        empty_grid_positions["gridBottom"] - empty_grid_positions["gridTop"] < 150
    end

    positions = nil
    wait_for(timeout: 5) do
      composer.image_grid.scroll_grid_to_editor_middle(index: 1)
      positions = composer.image_grid.control_positions(index: 1)

      positions["gridTop"] < positions["editorTop"] &&
        positions["gridBottom"] > positions["editorBottom"] &&
        positions["modeTop"] >= positions["editorTop"] &&
        positions["modeTop"] <= positions["editorTop"] + 20 &&
        positions["removeBottom"] <= positions["editorBottom"] &&
        positions["removeBottom"] >= positions["editorBottom"] - 20 &&
        positions["modeBottom"] < positions["removeTop"]
    end
  end
end
