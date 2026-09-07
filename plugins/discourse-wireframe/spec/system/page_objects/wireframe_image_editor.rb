# frozen_string_literal: true

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
          has_no_css?(".wireframe-image-editor-menu .d-position-picker") &&
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
        within(".wireframe-panel.--right") { click_button("Raw JSON") }
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
        within(".wireframe-panel.--right") { click_button("Raw JSON") }
        find(".wireframe-panel.--right").click_button("Collapse panel")
      end

      def has_focused_image_settings?
        has_css?(".wireframe-panel.--right .wireframe-image-field :focus") &&
          has_css?(".wireframe-panel.--right .d-position-picker")
      end

      def has_grid_sizing_notice?
        has_css?(".wireframe-image-field__frame", text: "Size controlled by the grid.") &&
          has_no_css?(".wireframe-image-field__frame input") &&
          has_no_css?(".wireframe-image-resize-overlay")
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
        within(".wireframe-inspector-form .d-position-picker") do
          fill_in("X (%)", with: x)
          fill_in("Y (%)", with: y)
          find("input", match: :first).click
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
