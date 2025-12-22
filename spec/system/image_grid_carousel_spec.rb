# frozen_string_literal: true

describe "Image Grid Carousel", type: :system do
  fab!(:current_user, :admin)
  let(:composer) { PageObjects::Components::Composer.new }
  let(:topic_page) { PageObjects::Pages::Topic.new }

  before { sign_in(current_user) }

  it "renders a carousel in the post stream" do
    upload1 =
      UploadCreator.new(file_from_fixtures("logo.png", "images"), "logo.png").create_for(
        current_user.id,
      )
    upload2 =
      UploadCreator.new(file_from_fixtures("logo.jpg", "images"), "logo.jpg").create_for(
        current_user.id,
      )

    post = create_post(raw: <<~MD)
      [grid mode=focus]
      ![logo|100x100](#{upload1.short_url})
      ![logo|100x100](#{upload2.short_url})
      [/grid]
    MD

    topic_page.visit_topic(post.topic, post_number: post.post_number)
    carousel = PageObjects::Components::ImageGridCarousel.new(post.post_number)

    expect(carousel).to have_carousel
    expect(carousel).to have_mode("focus")
    expect(carousel).to have_track
    expect(carousel).to have_slides(count: 2)
  end

  it "supports stage mode" do
    upload1 =
      UploadCreator.new(file_from_fixtures("logo.png", "images"), "logo.png").create_for(
        current_user.id,
      )
    upload2 =
      UploadCreator.new(file_from_fixtures("logo.jpg", "images"), "logo.jpg").create_for(
        current_user.id,
      )

    post = create_post(raw: <<~MD)
      [grid mode=stage]
      ![logo|100x100](#{upload1.short_url})
      ![logo|100x100](#{upload2.short_url})
      [/grid]
    MD

    topic_page.visit_topic(post.topic, post_number: post.post_number)
    carousel = PageObjects::Components::ImageGridCarousel.new(post.post_number)

    expect(carousel).to have_mode("stage")
    expect(carousel).to have_active_slide
  end

  it "allows changing modes in the rich text editor", js: true do
    SiteSetting.rich_editor = true
    SiteSetting.post_menu_hidden_items = ""
    current_user.user_option.update!(composition_mode: 1)

    upload =
      UploadCreator.new(file_from_fixtures("logo.png", "images"), "logo.png").create_for(
        current_user.id,
      )

    post = create_post(raw: <<~MD)
      [grid mode=focus]
      ![logo|100x100](#{upload.short_url})
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
