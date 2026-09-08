# frozen_string_literal: true

require "chunky_png"

module PageObjects
  module Components
    class WireframeImageEditor < PageObjects::Components::Base
      def select_section
        find(".d-block-section").click(x: 10, y: 10)
      end

      def select_image
        find(".d-block-image-frame:has(img[alt='Discourse community'])").click
      end

      def select_grid_image
        find(".d-block-image-frame:has(img[alt='Grid image'])").click
      end

      def stretch_grid_image
        %w[align justify].each do |field|
          find(
            ".wireframe-inspector-container-args-form [data-name='#{field}'] label:has(input[value='stretch'])",
          ).click
        end
      end

      def select_heading
        find(".d-block-heading").click
      end

      def select_paragraph
        find(".d-block-paragraph").click
      end

      def select_button
        find('.wireframe-block-chrome[data-wf-block-name="button-link"]').click
      end

      def has_inspector_field?(label)
        has_css?(".wireframe-inspector__body .form-kit__container-title", text: label)
      end

      def use_tall_viewport
        page.driver.with_playwright_page do |pw_page|
          pw_page.set_viewport_size(width: 1400, height: 1600)
        end
      end

      def show_placement_fields
        find(".wireframe-inspector-container-args-form").execute_script(
          'this.scrollIntoView({ block: "end" })',
        )
      end

      def use_narrow_inspector
        use_inspector_width(260)
      end

      def use_inspector_width(width)
        find(".wireframe-shell").execute_script(
          'this.style.setProperty("--wf-right-rail", `${arguments[0]}px`)',
          width,
        )
      end

      def use_rtl_inspector
        find(".wireframe-inspector__body").execute_script('this.dir = "rtl"')
      end

      def has_rtl_page?
        has_css?("html[lang='ar'].rtl")
      end

      def has_position_marker?(x:, y:)
        has_css?(".wireframe-image-position-picker__pad") { |pad| pad.evaluate_script(<<~JS) }
            (() => {
              const pad = this.getBoundingClientRect();
              const thumb = this.querySelector('.wireframe-image-position-picker__thumb').getBoundingClientRect();
              const expectedX = pad.left + this.clientLeft + this.clientWidth * #{x} / 100;
              const expectedY = pad.top + this.clientTop + this.clientHeight * #{y} / 100;
              return Math.abs((thumb.left + thumb.right) / 2 - expectedX) < 1 &&
                Math.abs((thumb.top + thumb.bottom) / 2 - expectedY) < 1;
            })()
          JS
      end

      def with_zoomed_viewport(scale)
        page.driver.with_playwright_page do |pw_page|
          original = pw_page.viewport_size.transform_keys(&:to_sym)
          viewport = {
            width: (original[:width] / scale).round,
            height: (original[:height] / scale).round,
          }
          pw_page.set_viewport_size(**viewport)
          client = pw_page.context.new_cdp_session(pw_page)
          client.send_message(
            "Emulation.setDeviceMetricsOverride",
            params: {
              **viewport,
              deviceScaleFactor: scale,
              mobile: false,
            },
          )
          yield
        ensure
          client.send_message("Emulation.clearDeviceMetricsOverride")
          client.detach
          pw_page.set_viewport_size(**original)
        end
      end

      def has_zoomed_viewport?(scale)
        has_css?(".wireframe-shell") do |shell|
          shell.evaluate_script(
            "window.devicePixelRatio === #{scale} && window.innerWidth === #{(1400 / scale).round}",
          )
        end
      end

      def has_inspector_translation?(text)
        has_css?(".wireframe-inspector__tab", text: text)
      end

      def choose_top_left_position
        find(".wireframe-image-position-picker__pad").click(x: 10, y: 10)
      end

      def has_top_left_position?
        has_css?(".wireframe-image-position-picker input[aria-label='X (%)']") do |input|
          input.value == "0"
        end &&
          has_css?(".wireframe-image-position-picker input[aria-label='Y (%)']") do |input|
            input.value == "0"
          end
      end

      def has_ordered_source_dimensions?
        has_css?(".wireframe-image-field__source-label small", count: 2) do |dimensions|
          dimensions.evaluate_script(<<~JS)
            (() => {
              const walker = document.createTreeWalker(this, NodeFilter.SHOW_TEXT);
              const nodes = [];
              while (walker.nextNode()) {
                if (/[0-9]/.test(walker.currentNode.textContent)) nodes.push(walker.currentNode);
              }
              if (nodes.length !== 2) return false;
              const first = document.createRange();
              first.selectNodeContents(nodes[0]);
              const last = document.createRange();
              last.selectNodeContents(nodes[1]);
              return first.getBoundingClientRect().right < last.getBoundingClientRect().left;
            })()
          JS
        end
      end

      def has_contained_inspector_content?
        has_css?(".wireframe-inspector__body") { |body| body.evaluate_script(<<~JS) }
            (() => {
              const bounds = this.getBoundingClientRect();
              const elements = [...this.querySelectorAll('button, input:not([type="file"]), select, summary, .form-kit__container-title, .wireframe-image-composition__label, .wireframe-image-field__warning, .wireframe-image-field__upload-status')];
              const failures = elements.filter(element => element.checkVisibility({visibilityProperty: true})).filter(element => {
                const rect = element.getBoundingClientRect();
                return rect.left < bounds.left - 1 || rect.right > bounds.right + 1 ||
                  element.scrollWidth > element.clientWidth + 1;
              });
              return failures.length === 0;
            })()
          JS
      end

      def with_failed_upload
        page.driver.with_playwright_page do |pw_page|
          pattern = %r{/uploads\.json}
          handler = ->(route, _request) do
            route.fulfill(
              status: 422,
              contentType: "application/json",
              body: { errors: ["Upload rejected"] }.to_json,
            )
          end
          pw_page.route(pattern, handler, times: 1)
          yield
        ensure
          pw_page.unroute(pattern, handler:)
        end
      end

      def has_closed_source_error?
        has_css?(
          ".wireframe-image-field details:not([open]) .wireframe-image-field__warning",
          text: "Couldn't change the image",
        ) && has_no_source_progress?
      end

      def has_themed_zoom_track?
        has_css?(".wireframe-image-composition__zoom input[type='range']") do |slider|
          color = slider.evaluate_script(<<~JS).scan(/\d+/).first(3).map(&:to_i)
            getComputedStyle(this.closest('.wireframe-image-composition').querySelector('.wireframe-image-position-picker__pad')).backgroundColor
          JS
          page.driver.with_playwright_page do |pw_page|
            png =
              ChunkyPNG::Image.from_blob(
                pw_page.locator(
                  ".wireframe-image-composition__zoom input[type='range']",
                ).screenshot,
              )
            pixel = png[png.width / 2, png.height / 2]
            [ChunkyPNG::Color.r(pixel), ChunkyPNG::Color.g(pixel), ChunkyPNG::Color.b(pixel)].zip(
              color,
            )
              .all? { |actual, expected| (actual - expected).abs <= 3 }
          end
        end
      end

      def change_zoom_with_keyboard(key)
        find(".wireframe-image-composition__zoom input[type='range']").send_keys(key)
      end

      def has_image_zoom?(value)
        has_css?(".wireframe-image-composition__zoom input[type='number']") do |input|
          input.value == value.to_s
        end
      end

      def remove_default_source
        within(".wireframe-panel.--right .wireframe-image-field__variant") do
          click_button("Remove image")
        end
      end

      def has_empty_image_chooser?
        has_css?(".wireframe-image-field__empty .file-uploader") &&
          has_no_css?(".wireframe-image-field summary") &&
          has_no_css?(".wireframe-image-field__dark") &&
          has_no_css?(".wireframe-image-field__frame") &&
          has_css?(".wireframe-inspector-form .form-kit__field.has-error", text: "Required.")
      end

      def has_clear_section_hierarchy?
        has_css?(".wireframe-inspector__body") { |body| body.evaluate_script(<<~JS) }
            (() => {
              const headings = [...this.querySelectorAll('.wireframe-image-composition__heading, .wireframe-image-field__frame legend, .form-kit__section-title')];
              const label = this.querySelector('.form-kit__container-title');
              const source = this.querySelector('.wireframe-image-field__source-label');
              const gridAction = this.querySelector('.wireframe-image-field__grid .btn');
              const placement = this.querySelector('.wireframe-inspector-container-args-form');
              if (headings.length < 4 || !label || !placement) return false;
              const size = el => parseFloat(getComputedStyle(el).fontSize);
              return size(source) === size(label) && size(gridAction) >= 12 &&
                headings.every(heading => size(heading) > size(label) && size(heading) === size(headings[0])) &&
                parseFloat(getComputedStyle(placement).borderTopWidth) > 0 &&
                parseFloat(getComputedStyle(placement).paddingTop) >= 16 &&
                parseFloat(getComputedStyle(placement).marginTop) >= 16;
            })()
          JS
      end

      def open_source(variant: :default)
        selector =
          variant == :dark ? ".wireframe-image-field__dark" : ".wireframe-image-field__variant"
        within(".wireframe-panel.--right #{selector}") do
          find("summary").click unless has_css?(".wireframe-image-field__tabs", wait: 0)
          find("[role='tab']", text: "Upload", exact_text: true).click
        end
      end

      def has_compact_source_chooser?
        has_css?(".wireframe-image-field__variant[open]") do |source|
          source.has_css?("summary img", count: 1) && source.has_no_css?(".lightbox") &&
            source.has_button?("Remove image") &&
            source.has_css?(".file-uploader__preview") do |chooser|
              chooser.evaluate_script("this.getBoundingClientRect().height <= 80")
            end
        end
      end

      def upload_default_source(path)
        within(".wireframe-panel.--right .wireframe-image-field__variant") do
          attach_file(path, make_visible: true)
        end
      end

      def has_uploaded_grid_image?
        has_css?("img[alt='Grid image'][src*='/uploads/']")
      end

      def drop_source(path, variant: :default)
        source =
          variant == :dark ? ".wireframe-image-field__dark" : ".wireframe-image-field__variant"
        page.driver.with_playwright_page do |pw_page|
          pw_page.locator("#{source} summary").evaluate(
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

      def has_closed_source_progress?
        has_css?(".wireframe-image-field details:not([open]) summary[aria-busy='true']") do |source|
          source.has_css?("progress") { |progress| progress.evaluate_script(<<~JS) }
              (() => {
                const bar = this.getBoundingClientRect();
                const status = this.parentElement;
                const range = document.createRange();
                const text = [...status.childNodes].find(node => node.nodeType === Node.TEXT_NODE && node.textContent.trim());
                if (!text) return false;
                range.selectNode(text);
                const label = range.getBoundingClientRect();
                const row = this.closest('summary').getBoundingClientRect();
                return bar.width >= 16 && bar.height > 0 && bar.left > label.right &&
                  Math.abs((bar.top + bar.bottom - label.top - label.bottom) / 2) < 2 &&
                  bar.right <= row.right;
              })()
            JS
        end
      end

      def has_no_source_progress?
        has_no_css?(".wireframe-image-field progress")
      end

      def has_uploaded_closed_sources?
        has_css?(
          ".wireframe-image-field details:not([open]) summary img[src*='/uploads/']",
          count: 2,
        )
      end

      def remove_dark_source
        within(".wireframe-panel.--right .wireframe-image-field__dark") do
          click_button("Remove image")
        end
      end

      def has_no_dark_grid_image?
        has_no_css?(".d-block-image-frame:has(img[alt='Grid image']) source", visible: false)
      end

      def click_outside_blocks
        find(".welcome-banner__title").click
      end

      def has_no_selected_block?
        has_no_css?(".wireframe-block-chrome.--selected")
      end

      def undo
        find(".wireframe-btn-undo").click
      end

      def redo
        find(".wireframe-btn-redo").click
      end

      def open_image_menu
        find(".wireframe-block-chrome.--selected .wireframe-block-toolbar").click_button(
          "Edit image",
        )
      end

      def has_no_image_menu?
        has_no_css?(".wireframe-image-editor-menu")
      end

      def has_compact_image_menu?
        has_css?(".wireframe-image-editor-menu", text: /Change.*image/) &&
          has_css?(".wireframe-image-editor-menu", text: "Show image settings") &&
          has_no_css?(".wireframe-image-editor-menu .wireframe-image-position-picker") &&
          has_no_css?(".wireframe-image-editor-menu input[type='number']") &&
          has_no_css?(".wireframe-image-editor-menu .wireframe-image-field")
      end

      def set_menu_fit
        within(".wireframe-image-editor-menu") do
          find("label", text: "Fit", exact_text: true).click
        end
      end

      def has_inline_menu_fit?
        has_css?(".wireframe-image-editor-menu .wireframe-image-composition__fit") do |row|
          row.evaluate_script(<<~JS)
            (() => {
              const label = this.querySelector('span').getBoundingClientRect();
              const control = this.querySelector('.wireframe-segmented-field').getBoundingClientRect();
              return label.right <= control.left && Math.abs(label.y + label.height / 2 - control.y - control.height / 2) < 2;
            })()
          JS
        end
      end

      def has_grouped_image_actions?
        has_css?(".wireframe-image-editor-menu") { |menu| menu.evaluate_script(<<~JS) }
            (() => {
              const fit = this.querySelector('.wireframe-image-composition__fit');
              const reposition = this.querySelector('.wireframe-image-composition__actions');
              const source = this.querySelector(':scope > .wireframe-image-editor-menu__action');
              const footer = this.querySelector('.wireframe-image-editor-menu__footer');
              const separators = [...this.querySelectorAll('hr')];
              if (!fit || !reposition || !source || separators.length !== (footer ? 2 : 1)) {
                return false;
              }
              const bounds = element => element.getBoundingClientRect();
              return bounds(fit).bottom <= bounds(reposition).top &&
                bounds(reposition).bottom <= bounds(separators[0]).top &&
                bounds(separators[0]).bottom <= bounds(source).top &&
                separators.every(separator => parseFloat(getComputedStyle(separator).borderTopWidth) > 0) &&
                (!footer || bounds(separators[1]).bottom <= bounds(footer).top);
            })()
          JS
      end

      def reposition_from_menu
        within(".wireframe-image-editor-menu") { click_button("Reposition", exact: true) }
      end

      def change_image(path)
        within(".wireframe-image-editor-menu") do
          attach_file("wireframe-image-upload-current", path, make_visible: true)
        end
      end

      def add_dark_image(path)
        within(".wireframe-image-editor-menu") do
          expect(page).to have_button("Add dark variant")
          attach_file("wireframe-image-upload-dark", path, make_visible: true)
        end
      end

      def use_color_mode(mode)
        page.driver.with_playwright_page { |pw_page| pw_page.emulate_media(colorScheme: mode) }
      end

      def use_short_viewport
        page.driver.with_playwright_page do |pw_page|
          pw_page.set_viewport_size(width: 1400, height: 900)
        end
      end

      def has_default_image_fallback?
        has_button?("Change default image") && has_no_css?(".wireframe-image-editor-menu__hint")
      end

      def has_change_dark_image?
        has_button?("Change dark image")
      end

      def has_matching_variant_action?
        has_css?(".wireframe-image-editor-menu") { |menu| menu.evaluate_script(<<~JS) }
            (() => {
              const image = document.querySelector('img[alt="Grid image"]');
              const dark = image.currentSrc.includes('/images/d-logo-sketch.png');
              const label = dark ? 'Change dark image' : 'Change light image';
              return [...this.querySelectorAll('button')].some(button => button.textContent.trim() === label);
            })()
          JS
      end

      def has_shared_composition_hint?
        has_css?(".wireframe-image-editor-menu", text: "Applies to both variants")
      end

      def dark_source
        find(".d-block-image-frame:has(img[alt='Discourse community']) source", visible: false)[
          "srcset"
        ]
      end

      def has_replaced_dark_source?(previous)
        has_css?(
          ".d-block-image-frame:has(img[alt='Discourse community']) source",
          visible: false,
        ) { |source| source["srcset"].include?("/uploads/") && source["srcset"] != previous }
      end

      def has_visible_dark_upload?
        has_css?("img[alt='Discourse community']") do |image|
          image.evaluate_script(
            "this.currentSrc.includes('/uploads/') && this.src.includes('/images/discourse-logo-sketch.png')",
          )
        end
      end

      def has_visible_default_image?
        has_css?("img[alt='Discourse community']") do |image|
          image.evaluate_script("this.currentSrc.includes('/images/discourse-logo-sketch.png')")
        end
      end

      def has_toolbar_anchored_menu?
        has_css?(".wireframe-image-editor-menu") { |menu| menu.evaluate_script(<<~JS) }
            (() => {
              const trigger = document.querySelector('.wireframe-block-chrome.--selected button[title="Edit image"]').getBoundingClientRect();
              const menu = this.getBoundingClientRect();
              return Math.abs(menu.top - trigger.bottom) < trigger.height && menu.left <= trigger.right && menu.right >= trigger.left;
            })()
          JS
      end

      def has_no_inspector_shortcut?
        has_no_css?(".wireframe-image-editor-menu__footer")
      end

      def has_inspector_shortcut?
        has_css?(".wireframe-image-editor-menu__footer", text: "Show image settings")
      end

      def has_focused_dark_image_settings?
        has_css?(".wireframe-panel.--right .wireframe-image-field__dark :focus")
      end

      def close_image_menu
        page.send_keys(:escape)
      end

      def show_raw_json
        within(".wireframe-panel.--right") { click_button("JSON") }
      end

      def has_uploaded_image?
        has_css?(".d-block-image-frame img[alt='Discourse community'][src*='/uploads/']")
      end

      def has_image_fit?
        has_css?(
          ".d-block-image-frame[style*='--block-image-fit: contain']:has(img[alt='Discourse community'])",
        )
      end

      def show_more_image_settings
        within(".wireframe-image-editor-menu") { click_button("Show image settings") }
      end

      def hide_image_settings
        within(".wireframe-panel.--right") { click_button("JSON") }
        find(".wireframe-panel.--right").click_button("Collapse panel")
      end

      def has_focused_image_settings?
        has_css?(".wireframe-panel.--right .wireframe-image-field :focus") &&
          has_css?(".wireframe-panel.--right .wireframe-image-position-picker")
      end

      def has_grid_sizing_notice?
        has_css?(".wireframe-image-field__frame", text: "Size controlled by the grid.") &&
          has_no_css?(".wireframe-image-field__frame input") &&
          has_no_css?(".wireframe-image-resize-overlay")
      end

      def has_compact_source_rows?
        has_css?(".wireframe-image-field__source", count: 2) do |source|
          source.evaluate_script(<<~JS)
            (() => {
              const preview = this.querySelector('img').getBoundingClientRect();
              const label = this.querySelector('.wireframe-image-field__source-label').getBoundingClientRect();
              const chevron = this.querySelector(':scope > .d-icon').getBoundingClientRect();
              return preview.right <= label.left && label.right <= chevron.left &&
                Math.abs(preview.top + preview.height / 2 - label.top - label.height / 2) < 1;
            })()
          JS
        end
      end

      def has_no_independent_frame_controls?
        has_no_css?(".wireframe-image-field__info") &&
          has_no_css?(".wireframe-block-chrome.--selected button[title='Reset frame size']")
      end

      def owning_grid_key
        find("img[alt='Grid image']").evaluate_script(
          "this.closest('[data-wf-block-name=layout]').dataset.wfBlockKey",
        )
      end

      def edit_grid
        within(".wireframe-image-field__frame") { click_button("Edit grid") }
      end

      def has_selected_grid?(key)
        has_css?(".wireframe-block-chrome.--selected[data-wf-block-key='#{key}']") &&
          has_css?(".wireframe-inspector__block-name", text: "Grid")
      end

      def has_positioned_resize_handles?
        positions = {
          "nw" => [0, 0],
          "n" => [0.5, 0],
          "ne" => [1, 0],
          "e" => [1, 0.5],
          "se" => [1, 1],
          "s" => [0.5, 1],
          "sw" => [0, 1],
          "w" => [0, 0.5],
        }

        has_css?(".wireframe-image-resize-overlay__handle", count: 8) do |handle|
          geometry = handle.evaluate_script(<<~JS)
            (() => {
              const frame = this.closest('.wireframe-block-chrome').querySelector('.d-block-image-frame').getBoundingClientRect();
              const handle = this.getBoundingClientRect();
              return { x: handle.x + handle.width / 2 - frame.x, y: handle.y + handle.height / 2 - frame.y, width: frame.width, height: frame.height };
            })()
          JS
          x, y = positions.fetch(handle["data-resize-handle"])
          (geometry["x"] - geometry["width"] * x).abs <= 2 &&
            (geometry["y"] - geometry["height"] * y).abs <= 2
        end
      end

      def image_dimensions
        find(".d-block-image-frame:has(img[alt='Discourse community'])").evaluate_script(
          "({ width: this.getBoundingClientRect().width, height: this.getBoundingClientRect().height })",
        )
      end

      def resize_image(x:, y:)
        drag_with_pointer(
          from: ".wireframe-image-resize-overlay__handle[data-resize-handle='se']",
          by: {
            x:,
            y:,
          },
        )
      end

      def has_image_dimensions?(width:, height:)
        has_css?(".d-block-image-frame:has(img[alt='Discourse community'])") do |frame|
          dimensions = frame.evaluate_script("this.getBoundingClientRect().toJSON()")
          (dimensions["width"] - width).abs <= 1 && (dimensions["height"] - height).abs <= 1
        end
      end

      def has_composition_controls?
        has_css?(".wireframe-inspector-form .wireframe-image-composition")
      end

      def grid_frame_widths
        frame = find(".d-block-layout__cell .d-block-image-frame")
        frame.evaluate_script(
          "[this.offsetWidth, this.closest('.wireframe-block-chrome__content').clientWidth]",
        )
      end

      def set_position(x:, y:)
        within(".wireframe-inspector-form .wireframe-image-position-picker") do
          find("input[aria-label='X (%)']").fill_in(with: x)
          find("input[aria-label='Y (%)']").fill_in(with: y)
          find("input", match: :first).click
        end
      end

      def has_aligned_unit_controls?(compact: false)
        has_css?(".wireframe-inspector-form .wireframe-image-composition") do |composition|
          composition.evaluate_script(<<~JS)
            (() => {
              const fields = [...this.querySelectorAll('.form-kit__control-input-wrapper')];
              if (fields.length !== 3) { return false; }
              const reference = fields[0].getBoundingClientRect();
              const container = this.getBoundingClientRect();
              return fields.every((field, index) => {
                const rect = field.getBoundingClientRect();
                const input = field.querySelector('input').getBoundingClientRect();
                const unit = field.querySelector('.form-kit__after-input').getBoundingClientRect();
                const keys = #{compact} && index === 2 ? ['width', 'height'] : ['width', 'height', 'left', 'right'];
                return keys.every(key => Math.abs(rect[key] - reference[key]) < 1) &&
                  rect.left >= container.left && rect.right <= container.right &&
                  Math.abs(input.height - unit.height) < 1;
              });
            })()
          JS
        end
      end

      def has_readable_coordinate_controls?
        has_css?(
          ".wireframe-inspector-form .wireframe-image-position-picker__coordinates",
        ) { |coordinates| coordinates.evaluate_script(<<~JS) }
            (() => {
              const fields = [...this.querySelectorAll('.form-kit__control-input-wrapper')];
              if (fields.length !== 2) return false;
              const focused = this.querySelector('input:focus');
              if (!focused || getComputedStyle(focused).outlineStyle === 'none' ||
                  parseFloat(getComputedStyle(focused).outlineWidth) < 2) return false;
              const context = document.createElement('canvas').getContext('2d');
              return fields[1].getBoundingClientRect().top - fields[0].getBoundingClientRect().bottom >= 8 &&
                fields.every(field => {
                  const input = field.querySelector('input');
                  const style = getComputedStyle(input);
                  const axis = field.parentElement.querySelector('.wireframe-image-position-picker__axis');
                  if (!axis || field.contains(axis)) return false;
                  const suffix = getComputedStyle(field.querySelector('.form-kit__after-input'));
                  context.font = style.font;
                  const padding = parseFloat(style.paddingLeft) + parseFloat(style.paddingRight);
                  const contentWidth = input.clientWidth - padding;
                  return field.getBoundingClientRect().height >= 32 &&
                    contentWidth >= context.measureText('100').width + 2 &&
                    parseFloat(style.borderInlineStartWidth) > 0 &&
                    parseFloat(style.borderInlineEndWidth) > 0 &&
                    parseFloat(suffix.borderInlineStartWidth) > 0;
                });
            })()
          JS
      end

      def has_contained_inspector_actions?
        has_css?(".wireframe-panel.--right") { |panel| panel.evaluate_script(<<~JS) }
            (() => {
              const tabs = this.querySelector('.wireframe-inspector__tabs');
              const composition = this.querySelector('.wireframe-image-composition');
              const contained = (parent, children) => {
                const bounds = parent.getBoundingClientRect();
                return [...children].every(child => {
                  const rect = child.getBoundingClientRect();
                  return rect.left >= bounds.left && rect.right <= bounds.right &&
                    child.scrollWidth <= child.clientWidth;
                });
              };
              const firstTab = tabs.firstElementChild.getBoundingClientRect();
              const inspectorFontSize = parseFloat(getComputedStyle(this.querySelector('.wireframe-inspector-form')).fontSize);
              return [...tabs.children].every(tab =>
                Math.abs(tab.getBoundingClientRect().top - firstTab.top) < 1 &&
                parseFloat(getComputedStyle(tab).fontSize) >= inspectorFontSize &&
                parseFloat(getComputedStyle(tab).paddingInlineStart) >= 4 &&
                parseFloat(getComputedStyle(tab).paddingInlineEnd) >= 4
              ) && contained(tabs, tabs.children) &&
                contained(composition, composition.querySelectorAll('.wireframe-image-composition__actions button'));
            })()
          JS
      end

      def has_aligned_inspector_selections?
        has_css?(".wireframe-inspector__body") { |body| body.evaluate_script(<<~JS) }
            [...this.querySelectorAll('.d-segmented-control')].filter(control => control.getBoundingClientRect().width > 0).every(control => {
              const selected = control.querySelector('input:checked').closest('label');
              const slider = control.querySelector('.d-segmented-control__slider');
              if (getComputedStyle(slider).display === 'none') {
                const background = getComputedStyle(selected).backgroundColor;
                const unselected = control.querySelector('input:not(:checked)').closest('label');
                return !['transparent', 'rgba(0, 0, 0, 0)'].includes(background) &&
                  background !== getComputedStyle(unselected).backgroundColor;
              }
              const label = selected.getBoundingClientRect();
              const highlight = slider.getBoundingClientRect();
              return ['left', 'top', 'width', 'height'].every(key => Math.abs(label[key] - highlight[key]) < 1);
            })
          JS
      end

      def has_paired_grid_coordinates?
        has_css?(".wireframe-inspector-container-args-form") { |form| form.evaluate_script(<<~JS) }
            (() => {
              const rect = name => this.querySelector(`[data-name="${name}"]`)?.getBoundingClientRect();
              const column = rect('column');
              const row = rect('row');
              const align = rect('align');
              const justify = rect('justify');
              if (!column || !row || !align || !justify) return false;
              const bounds = this.getBoundingClientRect();
              const rtl = getComputedStyle(this).direction === 'rtl';
              return Math.abs(column.top - row.top) < 1 && Math.abs(column.width - row.width) < 1 &&
                (rtl ? column.left - row.right : row.left - column.right) >= 8 &&
                Math.abs(align.width - bounds.width) < 1 && Math.abs(justify.width - bounds.width) < 1 &&
                align.top >= column.bottom && justify.top >= align.bottom;
            })()
          JS
      end

      def has_grouped_composition_controls?(compact: false, full_width_actions: false)
        has_css?(".wireframe-inspector-form .wireframe-image-composition") do |composition|
          composition.evaluate_script(<<~JS)
            (() => {
              const rect = selector => this.querySelector(selector)?.getBoundingClientRect();
              const coordinates = rect('.wireframe-image-position-picker__coordinates');
              const coordinateField = rect('.wireframe-image-position-picker__coordinates .form-kit__control-input-wrapper');
              const pad = rect('.wireframe-image-position-picker__pad');
              const fit = rect('.wireframe-image-composition__fit .wireframe-segmented-field');
              const number = rect('.wireframe-image-composition__zoom .form-kit__control-input-wrapper');
              const slider = rect('input[type="range"]');
              const action = rect('.wireframe-image-composition__actions');
              if (!coordinates || !coordinateField || !pad || !fit || !number || !slider || !action) return false;
              const rtl = getComputedStyle(this).direction === 'rtl';
              const start = rtl ? 'right' : 'left';
              const end = rtl ? 'left' : 'right';
              const bounds = this.getBoundingClientRect();
              const gap = rtl ? coordinates.left - pad.right : pad.left - coordinates.right;
              const close = (a, b) => Math.abs(a - b) < 1;
              const labelsFit = [...this.querySelectorAll('.wireframe-image-composition__fit, .wireframe-image-composition__position, .wireframe-image-composition__zoom')].every(row => {
                const range = document.createRange();
                range.selectNodeContents(row.firstElementChild);
                const label = range.getBoundingClientRect();
                const control = row.children[1].getBoundingClientRect();
                if (#{compact}) {
                  return row.classList.contains('wireframe-image-composition__position') ?
                    label.bottom + 4 <= control.top :
                    label.top < control.bottom && label.bottom > control.top &&
                      (rtl ? label.left - control.right >= 4 : control.left - label.right >= 4);
                }
                return rtl ? label.left - fit.right >= 4 : fit.left - label.right >= 4;
              });
              const aligned = #{compact} ?
                [fit, number, pad].every(box => close(box[end], bounds[end])) &&
                  [coordinates, slider].every(box => close(box[start], bounds[start])) &&
                  close(slider.width, bounds.width) :
                [coordinateField, number, slider].every(box => close(box[start], fit[start]));
              const actionAligned = #{full_width_actions} ?
                close(action[start], bounds[start]) && close(rect('.wireframe-image-composition__actions button').width, bounds.width) :
                close(action[start], fit[start]);
              return labelsFit && aligned && actionAligned && gap >= 4 && gap <= (#{compact} ? 32 : 16) && pad.width <= 80 && number.width <= 96 &&
                close(coordinates.top, pad.top) && close(coordinates.bottom, pad.bottom) &&
                close(pad.width, pad.height) &&
                slider.top > number.bottom && slider.width >= fit.width &&
                slider.left >= this.getBoundingClientRect().left &&
                slider.right <= this.getBoundingClientRect().right;
            })()
          JS
        end
      end

      def has_position?(x:, y:)
        has_css?(
          ".d-block-section__backdrop .d-block-image-frame[style*='--block-image-position: #{x}% #{y}%']",
        )
      end

      def has_no_position?(x:, y:)
        has_no_css?(
          ".d-block-section__backdrop .d-block-image-frame[style*='--block-image-position: #{x}% #{y}%']",
        )
      end

      def has_selected_section?
        has_css?(".wireframe-block-chrome.--selected[data-wf-block-name='section']")
      end

      def reposition
        within(".wireframe-image-composition") { click_button("Reposition on canvas") }
      end

      def has_adjustment?
        has_css?(".wireframe-image-reposition__surface")
      end

      def adjustment_geometry
        find(".wireframe-image-reposition").evaluate_script(<<~JS)
          (() => {
            const frame = document.querySelector('.d-block-section__backdrop .d-block-image-frame');
            return { overlay: this.getBoundingClientRect().toJSON(), frame: frame.getBoundingClientRect().toJSON(), chrome: this.closest('.wireframe-block-chrome').getBoundingClientRect().toJSON() };
          })()
        JS
      end

      def cancel_adjustment
        within(".wireframe-image-reposition") { click_button("Cancel") }
      end

      def nudge(*keys)
        find(".wireframe-image-reposition__surface").send_keys(*keys)
      end

      def finish_adjustment
        within(".wireframe-image-reposition") { click_button("Done") }
      end

      def has_no_adjustment?
        has_no_css?(".wireframe-image-reposition")
      end
    end
  end
end
