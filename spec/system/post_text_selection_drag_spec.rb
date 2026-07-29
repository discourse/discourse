# frozen_string_literal: true

describe "Post text selection | drag gate" do
  let(:topic_page) { PageObjects::Pages::Topic.new }
  fab!(:topic)
  fab!(:post) { Fabricate(:post, topic: topic, raw: "Hello world this is time for quoting") }
  fab!(:current_user, :admin)

  before { sign_in(current_user) }

  it "does not show the quote toolbar while the primary button is held, only on pointerup" do
    topic_page.visit_topic(topic)

    # Simulate an active drag: dispatch `pointerdown` (button 0) on the post, then
    # extend the selection WITHOUT releasing the button. The toolbar must not
    # appear while the button is held — previously it rendered mid-drag, sat on
    # top of the active selection endpoint, and perturbed the native selection,
    # causing the selection to flicker to the end of the page.
    page.execute_script(<<~JS)
      const cooked = document.querySelector("#{topic_page.post_by_number_selector(1)} .cooked p");
      const node = cooked.childNodes[0];
      cooked.dispatchEvent(new PointerEvent("pointerdown", { bubbles: true, button: 0, pointerType: "mouse" }));
      const sel = window.getSelection();
      const range = document.createRange();
      range.setStart(node, 0);
      range.setEnd(node, 10);
      sel.removeAllRanges();
      sel.addRange(range);
    JS

    # Past INPUT_DELAY (250ms) — the toolbar must NOT be present while held.
    sleep 0.4
    expect(page).not_to have_css(topic_page.copy_quote_button_selector)

    # Releasing the button finishes the drag — the toolbar should appear now.
    page.execute_script(<<~JS)
      window.dispatchEvent(new PointerEvent("pointerup", { button: 0, pointerType: "mouse" }));
    JS

    expect(page).to have_css(topic_page.copy_quote_button_selector)
  end

  it "shows the toolbar when a touch selection gesture ends in pointercancel" do
    topic_page.visit_topic(topic)

    # Touch long-press selections frequently end in `pointercancel` (the browser
    # takes over the gesture for its native selection handles) rather than
    # `pointerup`. The toolbar must still appear once the gesture ends.
    page.execute_script(<<~JS)
      const cooked = document.querySelector("#{topic_page.post_by_number_selector(1)} .cooked p");
      const node = cooked.childNodes[0];
      cooked.dispatchEvent(new PointerEvent("pointerdown", { bubbles: true, button: 0, pointerType: "touch" }));
      const sel = window.getSelection();
      const range = document.createRange();
      range.setStart(node, 0);
      range.setEnd(node, 10);
      sel.removeAllRanges();
      sel.addRange(range);
    JS

    # While the gesture is active the toolbar must NOT be present.
    sleep 0.4
    expect(page).not_to have_css(topic_page.copy_quote_button_selector)

    # The browser cancels the pointer to take over selection handles.
    page.execute_script(<<~JS)
      window.dispatchEvent(new PointerEvent("pointercancel", { bubbles: true, button: 0, pointerType: "touch" }));
    JS

    expect(page).to have_css(topic_page.copy_quote_button_selector)
  end
end
