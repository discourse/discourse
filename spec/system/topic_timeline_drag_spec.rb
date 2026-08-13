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

  it "lets the user scroll the topic by dragging down the timeline" do
    topic_page.visit_topic(topic)

    expect(topic_page).to have_post_number(1)
    expect(topic_page.timeline).to have_scroller

    # The pointer path is only exercised for real in a browser, where pointer
    # capture actually routes the drag back to the scroller. A synthetic dispatch
    # picks its own event target and so cannot tell a live drag from a dead one.
    topic_page.timeline.drag_to_bottom

    expect(topic_page.timeline).to have_scroller
    # Dragging to the foot of the timeline lands near the end of a 31-post topic.
    # Asserting on a late post rather than an exact index keeps this about "the
    # drag moved the topic" and not about the scroller's pixel-to-post rounding.
    expect(topic_page).to have_post_number(25)
  end

  it "clears the user's drag state when the pointer is released" do
    topic_page.visit_topic(topic)

    expect(topic_page).to have_post_number(1)
    expect(topic_page.timeline).to have_scroller

    topic_page
      .timeline
      .drag_by(y: 120) do
        # Asserted mid-gesture, because the absence afterwards is also what a drag
        # that never started would produce.
        expect(topic_page.timeline).to have_dragging_page
      end

    expect(topic_page.timeline).to have_no_dragging_page
  end
end
