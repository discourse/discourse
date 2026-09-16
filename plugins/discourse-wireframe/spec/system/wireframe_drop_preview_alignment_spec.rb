# frozen_string_literal: true

# Real-browser coverage for the slot-insert preview's geometry. The preview is a
# `position: fixed` overlay painted from viewport rects, so nothing but a real
# layout can tell whether it lands on the outlet it describes.
describe "Wireframe editor drop preview alignment" do
  fab!(:admin)

  let(:editor) { PageObjects::Pages::WireframeEditor.new }

  before do
    SiteSetting.wireframe_enabled = true
    sign_in(admin)
  end

  def box_of(selector)
    page.driver.with_playwright_page do |pw|
      el = pw.wait_for_selector(selector, state: "visible", timeout: 5000)
      b = el.bounding_box
      [b["x"], b["y"], b["width"], b["height"]]
    end
  end

  it "paints the drop preview over the empty outlet placeholder it targets" do
    visit("/latest")
    find(".wireframe-pill").click

    outlet =
      ".wireframe-outlet-boundary[data-outlet-name='sidebar-blocks'] .wireframe-block-chrome.--outlet-root"
    placeholder = "#{outlet} .wireframe-empty-drop-placeholder"
    expect(page).to have_css(placeholder, wait: 5)

    # The empty-state call to action is what the preview will trace, so it has
    # to sit inside the frame it belongs to before the preview can.
    frame = box_of(outlet)
    inner = box_of(placeholder)
    expect(inner[0]).to be >= frame[0]
    expect(inner[1]).to be >= frame[1]
    expect(inner[0] + inner[2]).to be <= frame[0] + frame[2]
    expect(inner[1] + inner[3]).to be <= frame[1] + frame[3]

    drag_and_hold(
      from: ".wireframe-block-tile[data-block-name='card']",
      over: placeholder,
      to: placeholder,
    ) do
      expect(page).to have_css(".wireframe-drop-preview", wait: 5)
      # Border included: the overlay's painted box, not its content box, is
      # what has to coincide with the placeholder.
      expected = box_of(placeholder)
      actual = box_of(".wireframe-drop-preview")
      expected.zip(actual).each { |e, a| expect(a).to be_within(1).of(e) }
    end
  end
end
