# frozen_string_literal: true

describe "Image Carousel" do
  fab!(:current_user, :admin)
  fab!(:upload1, :upload)
  fab!(:upload2, :upload)
  fab!(:upload3, :upload)

  let(:topic_page) { PageObjects::Pages::Topic.new }

  before { sign_in(current_user) }

  let!(:carousel_post) { create_post(raw: <<~MD) }
    [grid mode=carousel]
    ![logo|100x100](#{upload1.short_url})
    ![logo|100x100](#{upload2.short_url})
    ![logo|100x100](#{upload3.short_url})
    [/grid]
  MD

  context "in the post stream" do
    let(:carousel) { PageObjects::Components::ImageCarousel.new(carousel_post.post_number) }

    before { topic_page.visit_topic(carousel_post.topic, post_number: carousel_post.post_number) }

    # Swipe far enough to land in a wrap slot. :leading sits at scrollLeft = 0,
    # :trailing sits at the rightmost scroll position.
    def scroll_to_wrap(side)
      page.execute_script(<<~JS, side.to_s)
        const t = document.querySelector('.d-image-carousel__track');
        t.scrollTo({
          left: arguments[0] === 'leading' ? 0 : t.scrollWidth - t.clientWidth,
          behavior: 'instant',
        });
      JS
    end

    it "renders the carousel and its slides" do
      expect(carousel).to have_carousel
      expect(carousel).to have_track
      expect(carousel).to have_slides(count: 3)
    end

    it "wraps via prev/next buttons" do
      expect(carousel).to have_active_slide_index(0)

      carousel.click_prev
      expect(carousel).to have_active_slide_index(2)

      carousel.click_next
      expect(carousel).to have_active_slide_index(0)
    end

    it "wraps via keyboard arrows" do
      carousel.focus_track

      send_keys(:left)
      expect(carousel).to have_active_slide_index(2)

      wait_for_timeout(150) # let the prior animation settle before the next key
      send_keys(:right)
      expect(carousel).to have_active_slide_index(0)
    end

    it "wraps when scrolled into the trailing wrap slot" do
      carousel.click_next
      carousel.click_next
      expect(carousel).to have_active_slide_index(2)

      scroll_to_wrap(:trailing)
      expect(carousel).to have_active_slide_index(0)
    end

    it "wraps when scrolled into the leading wrap slot" do
      expect(carousel).to have_active_slide_index(0) # starting state + wait for render
      scroll_to_wrap(:leading)
      expect(carousel).to have_active_slide_index(2)
    end

    it "disables slide pointer-events during a button-triggered animation" do
      carousel.click_next
      expect(page).to have_css(".d-image-carousel__track.is-scrolling")
    end
  end

  it "allows changing modes in the composer" do
    SiteSetting.rich_editor = true
    SiteSetting.post_menu_hidden_items = ""
    current_user.user_option.update!(composition_mode: 1)

    topic_page.visit_topic(carousel_post.topic, post_number: carousel_post.post_number)
    topic_page.click_post_action_button(carousel_post, :edit)

    composer = PageObjects::Components::Composer.new
    expect(composer).to have_rich_editor_active

    composer.image_grid.select_mode("Grid")
    expect(composer.image_grid).to have_selected_mode("grid")

    composer.toggle_rich_editor
    expect(composer.composer_input.value).to include("[grid]")
  end
end
