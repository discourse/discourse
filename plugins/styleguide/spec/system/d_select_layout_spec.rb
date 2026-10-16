# frozen_string_literal: true

# Horizontal overflow is the one layout failure that is both obvious to a reader and invisible
# to every other gate: the suite stays green while the page scrolls sideways and content is
# cut off. Measuring the document against its own viewport catches it objectively.
#
# The original cause was a flex item with the default `min-width: auto`, which refuses to shrink
# below its content — so one wide example set the width of the entire page.
describe "UiKit | DSelect page layout" do
  fab!(:admin)

  # Every group, because a single wide example in any one of them pushes the whole page out.
  GROUPS = %w[start data states appearance content selection keyboard limits pickers]

  before do
    SiteSetting.styleguide_enabled = true
    sign_in(admin)
  end

  def horizontal_overflow
    page.evaluate_script(<<~JS)
      (function () {
        const doc = document.documentElement;
        return doc.scrollWidth - doc.clientWidth;
      })()
    JS
  end

  # A couple of pixels of rounding is not a layout bug; a cut-off column is.
  TOLERANCE = 2

  [1000, 1400].each do |width|
    it "does not scroll sideways at #{width}px" do
      resize_window(width: width) do
        GROUPS.each do |group|
          visit "/styleguide/molecules/select?group=#{group}"
          expect(page).to have_css("[data-test-styleguide-group='#{group}']")

          expect(horizontal_overflow).to be <= TOLERANCE,
          "the #{group} group overflows by #{horizontal_overflow}px at #{width}px wide"
        end
      end
    end
  end

  it "keeps the hero and its controls inside the viewport when space is tight" do
    resize_window(width: 900) do
      visit "/styleguide/molecules/select?group=start"
      expect(page).to have_css("[data-test-select-hero]")

      expect(horizontal_overflow).to be <= TOLERANCE
    end
  end
end
