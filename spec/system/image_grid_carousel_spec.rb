# frozen_string_literal: true

describe "Image Carousel", type: :system do
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
      [grid mode=focus]
      ![logo|100x100](#{upload1.short_url})
      ![logo|100x100](#{upload2.short_url})
      [/grid]
    MD

    topic_page.visit_topic(post.topic, post_number: post.post_number)
    carousel = PageObjects::Components::ImageCarousel.new(post.post_number)

    expect(carousel).to have_carousel
    expect(carousel).to have_mode("focus")
    expect(carousel).to have_track
    expect(carousel).to have_slides(count: 2)
  end

  it "supports stage mode" do
    post = create_post(raw: <<~MD)
      [grid mode=stage]
      ![logo|100x100](#{upload1.short_url})
      ![logo|100x100](#{upload2.short_url})
      [/grid]
    MD

    topic_page.visit_topic(post.topic, post_number: post.post_number)
    carousel = PageObjects::Components::ImageCarousel.new(post.post_number)

    expect(carousel).to have_mode("stage")
    expect(carousel).to have_active_slide
  end

  it "wraps around in focus mode" do
    post = create_post(raw: <<~MD)
      [grid mode=focus]
      ![logo|100x100](#{upload1.short_url})
      ![logo|100x100](#{upload2.short_url})
      [/grid]
    MD

    topic_page.visit_topic(post.topic, post_number: post.post_number)
    carousel = PageObjects::Components::ImageCarousel.new(post.post_number)

    expect(carousel).to have_active_slide_index(0)
    expect(carousel).not_to be_prev_button_disabled

    carousel.click_prev
    expect(carousel).to have_active_slide_index(1)

    carousel.click_next
    expect(carousel).to have_active_slide_index(0)

    carousel.click_next
    expect(carousel).to have_active_slide_index(1)

    expect(carousel).not_to be_next_button_disabled
    carousel.click_next
    expect(carousel).to have_active_slide_index(0)
  end

  it "wraps around in stage mode" do
    post = create_post(raw: <<~MD)
      [grid mode=stage]
      ![logo|100x100](#{upload1.short_url})
      ![logo|100x100](#{upload2.short_url})
      [/grid]
    MD

    topic_page.visit_topic(post.topic, post_number: post.post_number)
    carousel = PageObjects::Components::ImageCarousel.new(post.post_number)

    expect(carousel).to have_active_slide_index(0)
    expect(carousel).not_to be_prev_button_disabled

    carousel.click_prev
    expect(carousel).to have_active_slide_index(1)

    carousel.click_next
    expect(carousel).to have_active_slide_index(0)
  end

  it "keyboard navigation wraps around in focus mode" do
    post = create_post(raw: <<~MD)
      [grid mode=focus]
      ![logo|100x100](#{upload1.short_url})
      ![logo|100x100](#{upload2.short_url})
      [/grid]
    MD

    topic_page.visit_topic(post.topic, post_number: post.post_number)
    carousel = PageObjects::Components::ImageCarousel.new(post.post_number)

    carousel.focus_track

    send_keys(:left)
    expect(carousel).to have_active_slide_index(1)

    send_keys(:right)
    expect(carousel).to have_active_slide_index(0)
  end

  it "allows changing modes in the rich text editor", js: true do
    SiteSetting.rich_editor = true
    SiteSetting.post_menu_hidden_items = ""
    current_user.user_option.update!(composition_mode: 1)

    post = create_post(raw: <<~MD)
      [grid mode=focus]
      ![logo|100x100](#{upload1.short_url})
      [/grid]
    MD

    topic_page.visit_topic(post.topic, post_number: post.post_number)
    expect(topic_page).to have_post_action_button(post, :edit)
    topic_page.click_post_action_button(post, :edit)

    expect(composer).to be_opened
    expect(composer).to have_rich_editor_active
    expect(composer.image_grid).to have_mode_select

    composer.image_grid.select_mode("Stage")
    expect(composer.image_grid).to have_selected_mode("stage")

    composer.toggle_rich_editor
    expect(composer.composer_input.value).to include("[grid mode=stage]")
  end
end
