# frozen_string_literal: true

describe "Topic timeline scroller drag" do
  fab!(:current_user, :user)
  fab!(:topic)
  fab!(:post_1) { Fabricate(:post, topic: topic) }

  let(:topic_page) { PageObjects::Pages::Topic.new }

  before do
    sign_in(current_user)
    # Enough replies that the timeline renders a scroller with somewhere to travel.
    30.times { Fabricate(:post, topic: topic) }
  end

  def scrollarea_bottom
    page.evaluate_script(<<~JS)
      (() => {
        const area = document.querySelector(".timeline-scrollarea");
        const box = area.getBoundingClientRect();
        return box.top + box.height - 4;
      })()
    JS
  end

  it "scrolls the topic when the scroller is dragged down the timeline" do
    visit("/t/#{topic.slug}/#{topic.id}")

    expect(topic_page).to have_post_number(1)
    expect(page).to have_css(".timeline-scroller")

    # The pointer path is only exercised for real in a browser, where pointer
    # capture actually routes the drag back to the scroller. A synthetic dispatch
    # picks its own event target and so cannot tell a live drag from a dead one.
    drag_with_pointer(from: ".timeline-scroller", to: { x: 20, y: scrollarea_bottom })

    expect(page).to have_css(".timeline-scroller")
    # Dragging to the foot of the timeline lands near the end of a 31-post topic.
    # Asserting on a late post rather than an exact index keeps this about "the
    # drag moved the topic" and not about the scroller's pixel-to-post rounding.
    expect(topic_page).to have_post_number(25)
  end

  it "does not leave the page marked as dragging once the drag ends" do
    visit("/t/#{topic.slug}/#{topic.id}")

    expect(topic_page).to have_post_number(1)
    expect(page).to have_css(".timeline-scroller")

    drag_with_pointer(from: ".timeline-scroller", by: { y: 120 }) do
      # Asserted mid-gesture, because the absence afterwards is also what a drag
      # that never started would produce.
      expect(page).to have_css("body.dragging")
    end

    expect(page).to have_no_css("body.dragging")
  end
end
