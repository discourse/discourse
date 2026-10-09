# frozen_string_literal: true

describe "Topic timeline scroller drag" do
  fab!(:current_user, :user)
  fab!(:topic)
  fab!(:post_1) { Fabricate(:post, topic: topic) }
  # More replies than `TopicView::CHUNK_SIZE`, so a late post is only in the DOM
  # once the drag has actually moved the stream on.
  fab!(:replies) { 30.times.map { Fabricate(:post, topic: topic) } }

  let(:topic_page) { PageObjects::Pages::Topic.new }

  before { sign_in(current_user) }

  it "lets the user scroll the topic by dragging down the timeline" do
    topic_page.visit_topic(topic)

    expect(topic_page).to have_post_number(1)
    expect(topic_page.timeline).to have_scroller

    # The pointer path is only exercised for real in a browser, where pointer
    # capture actually routes the drag back to the scroller. A synthetic dispatch
    # picks its own event target and so cannot tell a live drag from a dead one.
    topic_page.timeline.drag_to_bottom

    # A later chunk had to load for this to be in the DOM at all.
    expect(topic_page).to have_post_number(25)
    # And the reader travelled with it. Asserted separately because the two can
    # come apart: a cloaked post keeps its `#post_N` id, so the assertion above
    # proves the stream advanced without saying where the reader ended up, and
    # the readout is computed from the drag rather than from what loaded.
    expect(topic_page.timeline).to have_position(31, 31)
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
        expect(topic_page.timeline).to have_dragging_scrollarea
      end

    expect(topic_page.timeline).to have_no_dragging_page
    expect(topic_page.timeline).to have_no_dragging_scrollarea
  end
end
