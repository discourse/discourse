# frozen_string_literal: true

module PageObjects
  module Components
    class WireframeCards < PageObjects::Components::Base
      def start_keyboard_navigation
        show_reference("card-keyboard")
        find('[data-block-id="card-keyboard"]').execute_script("this.tabIndex = -1; this.focus()")
      end

      def press_tab
        page.send_keys(:tab)
      end

      def follow_focused_link
        page.send_keys(:enter)
      end

      def has_focused_reader_link?(label)
        has_css?('[data-block-id="card-keyboard"] a:focus-visible') do |link|
          link.evaluate_script(<<~JS, label)
            (() => {
              const style = getComputedStyle(this);
              const name = this.getAttribute('aria-label') || this.textContent.trim();
              const bounds = this.getBoundingClientRect();
              const textRing = style.outlineStyle !== 'none' &&
                parseFloat(style.outlineWidth) > 0 && bounds.width > 0 && bounds.height > 0;
              const overlay = getComputedStyle(this, '::after');
              const card = this.closest('.d-block-card');
              const cardRing = overlay.outlineStyle !== 'none' &&
                parseFloat(overlay.outlineWidth) >= 2 &&
                parseFloat(overlay.outlineOffset) <= -parseFloat(overlay.outlineWidth) &&
                parseFloat(overlay.width) >= card.clientWidth - 1 &&
                parseFloat(overlay.height) >= card.clientHeight - 1;
              return name === arguments[0] && (textRing || cardRing);
            })()
          JS
        end
      end

      def click_exhibition_title
        show_reference("keyboard-actions")
        point =
          find('[data-block-id="keyboard-actions"] .d-block-card__title').evaluate_script(<<~JS)
          (() => {
            const bounds = this.getBoundingClientRect();
            return { x: bounds.left + bounds.width / 2, y: bounds.top + bounds.height / 2 };
          })()
        JS
        page.driver.with_playwright_page { |pw_page| pw_page.mouse.click(point["x"], point["y"]) }
      end

      def click_reader_link(label)
        within('[data-block-id="card-keyboard"]') { click_link(label) }
      end

      def show_reference(id)
        find("[data-block-id='#{id}']").execute_script(
          'this.style.scrollMarginTop = "160px"; this.scrollIntoView({ block: "start" })',
        )
      end

      def show_complete_reference(id)
        height =
          find("[data-block-id='#{id}']").evaluate_script("this.getBoundingClientRect().height")
        page.driver.with_playwright_page do |pw_page|
          pw_page.set_viewport_size(width: pw_page.viewport_size[:width], height: height.ceil + 240)
        end
        show_reference(id)
      end

      def has_complete_reference_in_view?(id)
        has_css?("[data-block-id='#{id}'] .d-block-card") { |card| card.evaluate_script(<<~JS) }
            (() => {
              const bounds = this.getBoundingClientRect();
              return bounds.width > 0 && bounds.height > 0 && bounds.top >= 0 &&
                bounds.bottom <= window.innerHeight && bounds.left >= 0 &&
                bounds.right <= document.documentElement.clientWidth;
            })()
          JS
      end

      def enlarge_text(direction:)
        @normal_title_size =
          find('[data-block-id="meta-sam"] .d-block-card__title').evaluate_script(
            "parseFloat(getComputedStyle(this).fontSize)",
          )
        page.execute_script(<<~JS, direction)
          const root = document.documentElement;
          root.dir = arguments[0];
          root.style.direction = arguments[0];
          root.style.fontSize = `${parseFloat(getComputedStyle(root).fontSize) * 2}px`;
        JS
      end

      def has_readable_image_controls?
        has_css?(".wireframe-inspector-form .wireframe-image-field") do |field|
          field.evaluate_script(<<~JS)
            (() => {
              const contained = (child, parent) => child.left >= parent.left - 1 && child.right <= parent.right + 1;
              const separated = (first, second) => first.bottom <= second.top + 1 || second.bottom <= first.top + 1 ||
                first.right <= second.left + 1 || second.right <= first.left + 1;
              const rows = [...this.querySelectorAll('.wireframe-image-composition__heading-content, .wireframe-image-composition__fit, .wireframe-image-composition__zoom')];
              const labels = [...this.querySelectorAll('.wireframe-image-field__source-label, .wireframe-image-composition__actions .d-button-label')];
              return rows.length === 3 && labels.length === 3 && rows.every(row => {
                const bounds = row.getBoundingClientRect();
                const children = [...row.children].map(child => child.getBoundingClientRect());
                return children.every((child, index) => contained(child, bounds) &&
                  children.slice(index + 1).every(peer => separated(child, peer)));
              }) && labels.every(label => {
                const bounds = label.getBoundingClientRect();
                if (!contained(bounds, label.parentElement.getBoundingClientRect())) return false;
                const walker = document.createTreeWalker(label, NodeFilter.SHOW_TEXT);
                for (let node; (node = walker.nextNode());) {
                  for (const match of node.textContent.matchAll(/\\S+/g)) {
                    const range = document.createRange();
                    range.setStart(node, match.index);
                    range.setEnd(node, match.index + match[0].length);
                    const boxes = [...range.getClientRects()];
                    if (!boxes.length || boxes.some(box => !contained(box, bounds) ||
                      Math.abs(box.top - boxes[0].top) > 1)) return false;
                  }
                }
                return true;
              });
            })()
          JS
        end
      end

      def show_image_controls
        field = find(".wireframe-inspector-form .wireframe-image-field")
        height = field.evaluate_script("this.getBoundingClientRect().height")
        page.driver.with_playwright_page do |pw_page|
          pw_page.set_viewport_size(width: pw_page.viewport_size[:width], height: height.ceil + 480)
        end
        field.execute_script('this.scrollIntoView({ block: "start" })')
      end

      def has_enlarged_rtl_text?
        has_css?('[data-block-id="meta-sam"] .d-block-card__title') do |title|
          title.evaluate_script(<<~JS, @normal_title_size)
            (() => {
              const style = getComputedStyle(this);
              return style.direction === 'rtl' && parseFloat(style.fontSize) >= arguments[0] * 1.9;
            })()
          JS
        end
      end

      def show_issues
        find('.wireframe-panel-switcher [role="tab"][aria-label^="Issues"]').click
      end

      def has_no_issues?
        has_css?(".wireframe-issues .panel-empty") && has_no_css?(".wireframe-issues__item")
      end

      def issue_messages
        find(".wireframe-issues").text
      end

      def allocate_stress_width(width)
        find('[data-block-id="card-stress"] .d-block-section__content').execute_script(
          "this.style.width = '#{width}px'; this.style.maxWidth = '100%'",
        )
      end

      def has_reference_cards?
        has_css?('[data-block-id="hubspot-dark-champion"]', text: "Gabriel Marguglio") &&
          has_css?('[data-block-id="hubspot-light-champion"]', text: "Cory Mitchell") &&
          has_css?('[data-block-id="andela-reference"]', text: "live channel cards") &&
          has_css?('[data-block-id="populii-atlas"] .d-block-card.--beside') &&
          has_css?('[data-block-id="meta-below"] .d-block-card.--below', count: 3)
      end

      def has_intact_stress_content?
        has_css?('[data-block-id="card-stress"] .d-block-card', count: 4) do |card|
          card.evaluate_script(<<~JS)
            (() => {
              const bounds = this.getBoundingClientRect();
              const fields = [...this.querySelectorAll('.d-block-card__title, .d-block-card__text, .d-block-card__meta, .d-block-card__identity, .d-block-card__actions')];
              return fields.length >= 5 && fields.every(field => {
                const box = field.getBoundingClientRect();
                return box.left >= bounds.left - 1 && box.right <= bounds.right + 1 &&
                  box.top >= bounds.top - 1 && box.bottom <= bounds.bottom + 1 &&
                  field.scrollWidth <= field.clientWidth + 1 && field.scrollHeight <= field.clientHeight + 1;
              });
            })()
          JS
        end
      end

      def show_museum
        find('[data-block-id="museum-cards"]').execute_script(
          'this.style.scrollMarginTop = "160px"; this.scrollIntoView({ block: "start" })',
        )
      end

      def show_media_stories
        find('[data-block-id="meta-cards"]').execute_script(
          'this.style.scrollMarginTop = "160px"; this.scrollIntoView({ block: "start" })',
        )
      end

      def use_wide_editor
        page.driver.with_playwright_page do |pw_page|
          pw_page.set_viewport_size(width: 2200, height: 1400)
        end
      end

      def use_narrow_reader
        page.driver.with_playwright_page do |pw_page|
          pw_page.set_viewport_size(width: 390, height: 844)
        end
      end

      def has_intact_reader_cards?(reference)
        has_css?("[data-block-id='#{reference}']") { |section| section.evaluate_script(<<~JS) }
            (() => {
              const cards = [...this.querySelectorAll('.d-block-card')];
              return cards.length > 0 && cards.every(card => {
                const bounds = card.getBoundingClientRect();
                const fields = [...card.querySelectorAll('.d-block-card__label, .d-block-card__title, .d-block-card__text, .d-block-card__meta, .d-block-card__identity, .d-block-card__actions')].filter(field =>
                  !(field.matches('.--empty') && getComputedStyle(field).display === 'none')
                );
                const separated = fields.every((field, index) => {
                  const box = field.getBoundingClientRect();
                  return fields.slice(index + 1).every(other => {
                    const peer = other.getBoundingClientRect();
                    return box.bottom <= peer.top + 1 || peer.bottom <= box.top + 1 ||
                      box.right <= peer.left + 1 || peer.right <= box.left + 1;
                  });
                });
                return bounds.left >= -1 && bounds.right <= document.documentElement.clientWidth + 1 &&
                  separated && fields.every(field => {
                    const box = field.getBoundingClientRect();
                    return box.left >= bounds.left - 1 && box.right <= bounds.right + 1 &&
                      box.top >= bounds.top - 1 && box.bottom <= bounds.bottom + 1 &&
                      field.scrollWidth <= field.clientWidth + 1 && field.scrollHeight <= field.clientHeight + 1;
                  });
              });
            })()
          JS
      end

      def select_speaker
        find('[data-block-id="meta-sam"] .d-block-card__title').click
      end

      def has_initials_in_identity_color?
        has_css?(
          '[data-block-id="meta-hawk"] .d-block-card__avatar',
          text: "H",
          exact_text: true,
        ) { |avatar| avatar.evaluate_script(<<~JS) }
            (() => {
              const style = getComputedStyle(this);
              const name = this.closest('.d-block-card__identity').querySelector('.d-block-card__identity-name');
              return style.color === getComputedStyle(name).color &&
                style.color !== style.backgroundColor;
            })()
          JS
      end

      def has_intact_reference_card?(reference)
        has_css?("[data-block-id='#{reference}'] .d-block-card") do |card|
          card.evaluate_script(<<~JS)
            (() => {
              const bounds = this.getBoundingClientRect();
              return bounds.width > 0 && bounds.left >= 0 &&
                bounds.right <= document.documentElement.clientWidth &&
                this.scrollWidth <= this.clientWidth + 1 &&
                this.scrollHeight <= this.clientHeight + 1;
            })()
          JS
        end
      end

      def select_story_without_body
        find('[data-block-id="meta-hawk"] .d-block-card__title').click
      end

      def show_optional_groups
        find('[data-inspector-group="identity"] > summary').execute_script(
          'this.scrollIntoView({ block: "center" })',
        )
      end

      def has_readable_group_headings?
        has_css?(".wireframe-inspector-form__advanced > summary", count: 5) do |summary|
          summary.evaluate_script(<<~JS)
            (() => {
              const form = this.closest('.wireframe-inspector-form');
              const heading = getComputedStyle(form.querySelector('.form-kit__section-title'));
              const style = getComputedStyle(this);
              return style.color === heading.color && style.fontSize === heading.fontSize &&
                Math.abs(this.getBoundingClientRect().width - form.getBoundingClientRect().width) < 1 &&
                this.scrollWidth <= this.clientWidth + 1;
            })()
          JS
        end
      end

      def has_distinct_media_sections?
        has_css?(
          ".wireframe-inspector-form .form-kit__section-title",
          text: "Media",
          exact_text: true,
        ) &&
          has_css?(
            "#control-image .wireframe-image-composition__heading-content > span",
            text: "Composition",
            exact_text: true,
          )
      end

      def has_optional_story_placeholders?
        has_css?(
          '[data-block-id="meta-hawk"] :is(.d-block-card__meta, .d-block-card__text)',
          count: 2,
        )
      end

      def has_no_optional_story_placeholders?
        has_no_css?('[data-block-id="meta-hawk"] :is(.d-block-card__meta, .d-block-card__text)')
      end

      def select_curator
        find('[data-block-id="museum-curator"] .d-block-card__title').click
      end

      def has_selected_curator?
        has_css?(
          '.wireframe-block-chrome.--selected [data-block-id="museum-curator"] .d-block-card',
        )
      end

      def has_reachable_media_identity?
        has_css?('[data-block-id="meta-sam"] .d-block-card__identity-name .wf-rich-text') do |name|
          name.evaluate_script(<<~JS)
            (() => {
              const bounds = this.getBoundingClientRect();
              const target = document.elementFromPoint(bounds.left + bounds.width / 2, bounds.top + bounds.height / 2);
              return target === this || this.contains(target);
            })()
          JS
        end
      end

      def edit_media_identity
        find('[data-block-id="meta-sam"] .d-block-card__identity-name .wf-rich-text').click
      end

      def has_focused_media_identity?
        has_css?(
          '[data-block-id="meta-sam"] .d-block-card__identity-name [contenteditable="true"]:focus',
        )
      end

      def position_speaker_image(region, x:, y:)
        field = region == :feature ? "image" : "avatar"
        within("#control-#{field}") do
          find("input[aria-label='X (%)']").fill_in(with: x)
          find("input[aria-label='Y (%)']").fill_in(with: y)
          find("input[aria-label='X (%)']").click
        end
      end

      def reposition_speaker_image(region)
        field = region == :feature ? "image" : "avatar"
        within("#control-#{field}") { click_button("Reposition on canvas") }
      end

      def has_focused_reposition?(region)
        field = region == :feature ? "image" : "avatar"
        has_css?("#control-#{field} button:focus", text: "Reposition on canvas")
      end

      def drop_speaker_source(path, region:, dark: false)
        field = region == :feature ? "image" : "avatar"
        variant = dark ? ".wireframe-image-field__dark" : ".wireframe-image-field__variant"
        page.driver.with_playwright_page do |pw_page|
          pw_page.locator("#control-#{field} #{variant} summary").evaluate(
            <<~JS,
              async (element, data) => {
                const file = new File([Uint8Array.from(atob(data), c => c.charCodeAt(0))], "replacement.png", { type: "image/png" });
                const dataTransfer = new DataTransfer();
                dataTransfer.items.add(file);
                const bounds = element.getBoundingClientRect();
                for (const type of ["dragenter", "dragover", "drop"]) {
                  element.dispatchEvent(new DragEvent(type, { bubbles: true, cancelable: true, dataTransfer,
                    clientX: bounds.x + bounds.width / 2, clientY: bounds.y + bounds.height / 2 }));
                  await new Promise(requestAnimationFrame);
                }
              }
            JS
            arg: Base64.strict_encode64(File.binread(path)),
          )
        end
      end

      def has_closed_source_progress?(region)
        field = region == :feature ? "image" : "avatar"
        has_css?("#control-#{field} details:not([open]) summary[aria-busy='true'] progress")
      end

      def has_uploaded_speaker_sources?(region, count:)
        field = region == :feature ? "image" : "avatar"
        has_css?("#control-#{field} details:not([open]) summary img[src*='/uploads/']", count:) &&
          has_no_css?("#control-#{field} progress") &&
          has_css?("[data-block-id='meta-sam'] [data-block-arg='#{field}'] img[src*='/uploads/']")
      end

      def remove_speaker_feature
        within("#control-image .wireframe-image-field__variant") do
          find("summary").click
          click_button("Remove image")
        end
      end

      def has_four_distinct_speaker_sources?
        has_css?(".wireframe-inspector-form") { |form| form.evaluate_script(<<~JS) }
            (() => {
              const sources = [...this.querySelectorAll('#control-image summary img, #control-avatar summary img')];
              return sources.length === 4 && new Set(sources.map(image => image.src)).size === 4;
            })()
          JS
      end

      def speaker_source_urls
        all("#control-image summary img, #control-avatar summary img", count: 4).map do |image|
          image[:src]
        end
      end

      def has_speaker_sources?(sources)
        has_css?(".wireframe-inspector-form") { |form| form.evaluate_script(<<~JS, sources) }
            (() => {
              const images = [...this.querySelectorAll('#control-image summary img, #control-avatar summary img')];
              return JSON.stringify(images.map(image => image.src)) === JSON.stringify(arguments[0]);
            })()
          JS
      end

      def has_empty_feature_chooser?
        has_css?("#control-image .wireframe-image-field__empty [role='tab']", text: "Upload") &&
          has_no_css?("#control-image .wireframe-image-field__dark") &&
          has_no_css?("[data-block-id='meta-sam'] [data-block-arg='image'] img")
      end

      def has_speaker_image_position?(region, x:, y:)
        argument = region == :feature ? "image" : "avatar"
        has_css?(
          "[data-block-id='meta-sam'] [data-block-arg='#{argument}'] .d-block-image-frame",
        ) do |frame|
          frame.evaluate_script("this.style.getPropertyValue('--block-image-position').trim()") ==
            "#{x}% #{y}%"
        end
      end

      def has_feature_prompt_inside_media?
        has_css?('[data-block-id="meta-sam"] .d-block-card__image') do |image|
          image.evaluate_script(<<~JS)
            (() => {
              const overlay = this.closest('.wireframe-block-chrome').querySelector('.wireframe-image-arg-overlay[data-block-arg="image"]');
              if (!overlay) { return false; }
              const media = this.getBoundingClientRect();
              const prompt = overlay.getBoundingClientRect();
              return ['top', 'right', 'bottom', 'left'].every(edge => Math.abs(media[edge] - prompt[edge]) <= 1);
            })()
          JS
        end
      end

      def toggle_identity_group
        find('[data-inspector-group="identity"] > summary').click
      end

      def fill_identity_name(name)
        find('#control-identityName [contenteditable="true"]').set(name)
      end

      def toggle_identity
        FormKitField.new('.form-kit__field[data-name="identityEnabled"]').toggle
      end

      def follow_identity_error_with_keyboard
        find('.form-kit__errors-summary a[href="#control-identityName"]').send_keys(:enter)
      end

      def has_identity_name_error?
        has_css?('.form-kit__errors-summary a[href="#control-identityName"]', text: "Name")
      end

      def has_no_identity_name_error?
        has_no_css?('.form-kit__errors-summary a[href="#control-identityName"]')
      end

      def has_focused_identity_name?
        has_css?('#control-identityName [contenteditable="true"]:focus') do |editor|
          editor.evaluate_script(<<~JS)
            (() => {
              const bounds = this.getBoundingClientRect();
              return bounds.height > 0 && bounds.width > 0 &&
                bounds.top >= 0 && bounds.bottom <= window.innerHeight;
            })()
          JS
        end
      end

      def has_identity_name?(name)
        has_css?('#control-identityName [contenteditable="true"]', text: name)
      end

      def has_speaker_identity?(name)
        has_css?('[data-block-id="meta-sam"] .d-block-card__identity', text: name)
      end

      def has_no_speaker_identity?(name = nil)
        has_no_css?('[data-block-id="meta-sam"] .d-block-card__identity', text: name)
      end

      def has_selected_speaker?
        has_css?('.wireframe-block-chrome.--selected [data-block-id="meta-sam"] .d-block-card')
      end

      def has_loaded_artwork?
        has_css?(".d-block-card__image img", minimum: 7) do |image|
          image.evaluate_script("this.complete && this.naturalWidth > 0")
        end
      end

      def speaker_artwork_url
        find('[data-block-id="meta-sam"] .d-block-card__image img')[:src]
      end

      def reload_reader_without_waiting_for_artwork
        page.driver.with_playwright_page { |pw_page| pw_page.reload(waitUntil: "domcontentloaded") }
      end

      def with_failed_artwork(url)
        page.driver.with_playwright_page do |pw_page|
          handler = ->(route, _request) { route.fulfill(status: 404, body: "Image unavailable") }
          pw_page.route(url, handler)
          yield
        ensure
          pw_page.unroute(url, handler:)
        end
      end

      def has_pending_speaker_artwork?
        has_css?('[data-block-id="meta-sam"] .d-block-card__image img') do |image|
          image.evaluate_script("!this.complete && this.naturalWidth === 0")
        end
      end

      def has_failed_speaker_artwork?
        has_css?('[data-block-id="meta-sam"] .d-block-card__image img') do |image|
          image.evaluate_script("this.complete && this.naturalWidth === 0")
        end
      end

      def has_loaded_speaker_artwork?
        has_css?('[data-block-id="meta-sam"] .d-block-card__image img') do |image|
          image.evaluate_script("this.complete && this.naturalWidth > 0")
        end
      end

      def has_podcast_icon?
        has_css?('[data-block-id="meta-sam"] .d-icon-headphones use') do |icon|
          icon.evaluate_script("this.getBBox().width > 0 && this.getBBox().height > 0")
        end
      end

      def has_no_image_warnings?
        has_no_css?(".wireframe-block-chrome.--unresolved-image")
      end

      def has_separated_card_groups?
        has_css?('[data-block-id="meta-cards"]') { |section| section.evaluate_script(<<~JS) }
            (() => {
              const stories = [...this.querySelectorAll('.d-block-card.--above')];
              const guide = this.querySelector('[data-block-id="meta-guide"] .d-block-card');
              return guide.getBoundingClientRect().top > Math.max(...stories.map(card => card.getBoundingClientRect().bottom)) + 8;
            })()
          JS
      end

      def has_filled_editorial_cell?
        has_css?('[data-block-id="museum-curator"] .d-block-card') do |card|
          card.evaluate_script(<<~JS)
            (() => {
              const card = this.getBoundingClientRect();
              const host = this.closest('.wireframe-block-chrome__content') || this.closest('.d-block-layout__cell');
              return Math.abs(card.bottom - host.getBoundingClientRect().bottom) < 1 && card.height > 300;
            })()
          JS
        end
      end

      def editorial_geometry
        find('[data-block-id="museum-curator"] .d-block-card').evaluate_script(<<~JS)
          (() => {
            const ancestors = [];
            for (let element = this; element && !element.matches('.d-block-layout'); element = element.parentElement) {
              const style = getComputedStyle(element);
              ancestors.push({ class: element.className, rect: element.getBoundingClientRect().toJSON(), boxSizing: style.boxSizing, display: style.display, minHeight: style.minHeight });
            }
            return ancestors;
          })()
        JS
      end

      def has_aligned_media_stories?
        has_css?('[data-block-id="meta-cards"]') { |section| section.evaluate_script(<<~JS) }
            (() => {
              const cards = [...this.querySelectorAll('.d-block-card.--above')];
              if (cards.length !== 3) return false;
              const reference = cards[0].getBoundingClientRect();
              const peers = cards.filter(card =>
                Math.abs(card.getBoundingClientRect().top - reference.top) < 1
              );
              if (peers.length < 2) return false;
              const edge = (card, selector) => card.querySelector(selector).getBoundingClientRect().bottom;
              return peers.every(card =>
                Math.abs(edge(card, '.d-block-card__media') - edge(peers[0], '.d-block-card__media')) < 1 &&
                Math.abs(edge(card, '.d-block-card__actions') - edge(peers[0], '.d-block-card__actions')) < 1
              );
            })()
          JS
      end

      def has_wrapped_media_stories?
        has_css?('[data-block-id="meta-cards"]') { |section| section.evaluate_script(<<~JS) }
            (() => {
              const cards = [...this.querySelectorAll('.d-block-card.--above')];
              if (cards.length !== 3) return false;
              const rows = [];
              for (const card of cards) {
                const top = card.getBoundingClientRect().top;
                const row = rows.find(peers => Math.abs(peers[0].getBoundingClientRect().top - top) < 1);
                if (row) row.push(card);
                else rows.push([card]);
              }
              const edge = (card, selector) => card.querySelector(selector).getBoundingClientRect().bottom;
              return rows.length > 1 && rows.every((peers, index) => {
                const nextRow = rows[index + 1];
                return peers.every(card =>
                  (!nextRow || card.getBoundingClientRect().bottom < nextRow[0].getBoundingClientRect().top) &&
                  Math.abs(edge(card, '.d-block-card__media') - edge(peers[0], '.d-block-card__media')) < 1 &&
                  Math.abs(edge(card, '.d-block-card__actions') - edge(peers[0], '.d-block-card__actions')) < 1
                );
              });
            })()
          JS
      end

      def media_story_height
        find('[data-block-id="meta-sam"] .d-block-card__media').evaluate_script(
          "this.getBoundingClientRect().height",
        )
      end

      def has_expanded_media_stories?(original_height)
        has_css?('[data-block-id="meta-cards"] .d-block-card__media', count: 3) do |media|
          media.evaluate_script("this.getBoundingClientRect().height") > original_height + 100
        end
      end

      def has_media_story_height?(height)
        has_css?('[data-block-id="meta-cards"] .d-block-card__media', count: 3) do |media|
          (media.evaluate_script("this.getBoundingClientRect().height") - height).abs < 1
        end
      end
    end
  end
end
