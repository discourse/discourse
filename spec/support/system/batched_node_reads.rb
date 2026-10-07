# frozen_string_literal: true
module SystemBatchedNodeReads
  READ_ELEMENT = <<~JS
    (element, readText) => {
      if (!element.isConnected) {
        throw new Error('Element is not attached to the DOM');
      }
      const visible = (() => {
        let current = element;
        if (current.tagName === 'AREA') {
          const mapName = document.evaluate('./ancestor::map/@name', current, null, XPathResult.STRING_TYPE, null).stringValue;
          current = document.querySelector(`img[usemap='#${mapName}']`);
          if (!current) {
            return false;
          }
        }
        let forcedVisible = false;
        while (current) {
          const style = window.getComputedStyle(current);
          if (style.visibility === 'visible') {
            forcedVisible = true;
          }
          if (style.display === 'none' ||
              (style.visibility === 'hidden' && !forcedVisible) ||
              parseFloat(style.opacity) === 0) {
            return false;
          }
          const parent = current.parentElement;
          if (parent && parent.tagName === 'DETAILS' && !parent.open && current.tagName !== 'SUMMARY') {
            return false;
          }
          current = parent;
        }
        return true;
      })();
      if (!readText) {
        return visible;
      }
      if (!visible) {
        return '';
      }
      return element.nodeName === 'TEXTAREA' || element instanceof SVGElement
        ? element.textContent : element.innerText;
    }
  JS
  private_constant :READ_ELEMENT

  def visible?
    read_element(read_text: false)
  end

  def visible_text
    read_element(read_text: true)
      .to_s
      .scrub
      .gsub(/\A[[:space:]&&[^\u00a0]]+/, "")
      .gsub(/[[:space:]&&[^\u00a0]]+\z/, "")
      .gsub(/\n+/, "\n")
      .tr("\u00a0", " ")
  end

  private

  def read_element(read_text:)
    @element.evaluate(READ_ELEMENT, arg: read_text)
  rescue Playwright::Error => error
    case error.message
    when /Element is not attached to the DOM/,
         /Execution context was destroyed, most likely because of a navigation/,
         /Cannot find context with specified id/,
         /Unable to adopt element handle from a different document/,
         /error in channel "content::page": exception while running method "adoptNode"/,
         /(: Shadow DOM element - no XPath :)/
      raise Capybara::Playwright::Node::StaleReferenceError.new(error)
    else
      raise
    end
  end
end

if ENV["DISCOURSE_SYSTEM_BATCHED_READS"] == "1"
  Capybara::Playwright::Node.prepend(SystemBatchedNodeReads)
end
