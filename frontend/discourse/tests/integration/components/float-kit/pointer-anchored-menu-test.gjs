import { click, find, focus, render, settled, tab } from "@ember/test-helpers";
import { module, test } from "qunit";
import ModalContainer from "discourse/components/modal-container";
import DMenu from "discourse/float-kit/components/d-menu";
import DMenus from "discourse/float-kit/components/d-menus";
import { forceMobile } from "discourse/lib/mobile";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import DButton from "discourse/ui-kit/d-button";

const CloseMenu = <template>
  <DButton class="close-menu" @action={{@close}}>Close menu</DButton>
</template>;

module(
  "Integration | Component | FloatKit | PointerAnchoredMenu",
  function (hooks) {
    setupRenderingTest(hooks);

    // Defect 1: frontend/discourse/float-kit/lib/d-menu-instance.ts:127 ignores a virtual trigger's focus target.
    test("pointer-oracle: closing a virtual-trigger menu resolves focusTarget at close time", async function (assert) {
      await render(
        <template>
          {{#if this.replaceTarget}}
            <button class="focus-target" type="button">Replacement target</button>
          {{else}}
            <button class="focus-target" type="button">Original target</button>
          {{/if}}
          <DMenus />
        </template>
      );

      const originalTarget = find(".focus-target");
      const anchorRect = originalTarget.getBoundingClientRect();
      const virtualTrigger = { getBoundingClientRect: () => anchorRect };
      await focus(originalTarget);

      await this.owner.lookup("service:menu").show(virtualTrigger, {
        component: CloseMenu,
        autofocus: false,
        focusTarget: () => find(".focus-target"),
      });
      await settled();
      assert
        .dom(".fk-d-menu .close-menu")
        .exists(
          "the virtual trigger and intended option render without throwing"
        );

      await focus(".close-menu");
      this.set("replaceTarget", true);
      await settled();

      const replacementTarget = find(".focus-target");
      assert.notStrictEqual(
        replacementTarget,
        originalTarget,
        "the focus destination is a new element created after opening"
      );
      assert.false(
        originalTarget.isConnected,
        "the original target is detached"
      );
      assert.dom(".close-menu").isFocused("the menu owns focus before closing");

      await click(".close-menu");

      assert.dom(".fk-d-menu").doesNotExist("the menu has closed");
      assert.strictEqual(
        document.activeElement,
        replacementTarget,
        "closing the virtual-trigger menu focuses the current focusTarget element"
      );
    });

    // Defect 2: frontend/discourse/float-kit/components/d-float-body.gts:145 emits an id with no label element.
    test("pointer-oracle: an idless service trigger gives the menu a usable label", async function (assert) {
      await render(
        <template>
          <button class="menu-trigger" type="button">Pointer actions</button>
          <DMenus />
        </template>
      );

      const trigger = find(".menu-trigger");
      const expectedLabel = trigger.textContent.trim();
      assert
        .dom(trigger)
        .doesNotHaveAttribute("id", "the service trigger has no id");

      await this.owner.lookup("service:menu").show(trigger, {
        component: CloseMenu,
        ariaLabel: expectedLabel,
        contentRole: "dialog",
      });
      await settled();

      const float = find(".fk-d-menu");
      assert
        .dom(float)
        .exists("the intended ariaLabel option does not prevent rendering");
      const labelledby = float.getAttribute("aria-labelledby");
      const labelReferencesResolve =
        !labelledby ||
        labelledby
          .trim()
          .split(/\s+/)
          .every((id) => document.getElementById(id));
      assert.true(
        labelReferencesResolve,
        "every aria-labelledby reference resolves to an element in the document"
      );
      assert
        .dom(float)
        .hasAttribute(
          "aria-label",
          expectedLabel,
          "the menu exposes the supplied label measured from its trigger"
        );
    });

    // Defect 3: frontend/discourse/app/ui-kit/modifiers/d-trap-tab.ts:94 retains a hidden first input.
    test("pointer-oracle: Tab wraps past a hidden input to the first visible control", async function (assert) {
      await render(
        <template>
          <DMenu
            @autofocus={{false}}
            @inline={{true}}
            @label="Actions"
            @trapTab={{true}}
          >
            <:content>
              <input aria-label="Hidden input" hidden />
              <input aria-label="Visible input" class="visible-input" />
              <button class="first-button" type="button">First action</button>
              <button class="last-button" type="button">Last action</button>
            </:content>
          </DMenu>
        </template>
      );

      await click(".fk-d-menu__trigger");
      const visibleInput = find(".fk-d-menu .visible-input");
      const firstButton = find(".fk-d-menu .first-button");
      const lastButton = find(".fk-d-menu .last-button");
      assert
        .dom(".fk-d-menu input[hidden]")
        .isNotVisible("the leading input is hidden");

      await focus(visibleInput);
      await tab();
      assert.strictEqual(
        document.activeElement,
        firstButton,
        "Tab reaches the first visible button"
      );
      await tab();
      assert.strictEqual(
        document.activeElement,
        lastButton,
        "Tab reaches the last visible button"
      );
      await tab();
      assert.strictEqual(
        document.activeElement,
        visibleInput,
        "Tab wraps to the visible input instead of stalling on the hidden input"
      );
    });

    // Defect 3: frontend/discourse/app/ui-kit/modifiers/d-trap-tab.ts:94 retains a CSS-hidden last input.
    test("pointer-oracle: Shift+Tab wraps past a CSS-hidden input to the last visible control", async function (assert) {
      await render(
        <template>
          <DMenu
            @autofocus={{false}}
            @inline={{true}}
            @label="Actions"
            @trapTab={{true}}
          >
            <:content>
              <button class="first-button" type="button">First action</button>
              <button class="last-button" type="button">Last action</button>
              <input aria-label="Visible input" class="visible-input" />
              <input
                aria-label="CSS-hidden input"
                class="css-hidden-input"
                style="display: none"
              />
            </:content>
          </DMenu>
        </template>
      );

      await click(".fk-d-menu__trigger");
      const firstButton = find(".fk-d-menu .first-button");
      const lastButton = find(".fk-d-menu .last-button");
      const visibleInput = find(".fk-d-menu .visible-input");
      assert
        .dom(".css-hidden-input")
        .isNotVisible("the trailing input is hidden by CSS");

      await focus(visibleInput);
      await tab({ backwards: true });
      assert.strictEqual(
        document.activeElement,
        lastButton,
        "Shift+Tab reaches the last visible button"
      );
      await tab({ backwards: true });
      assert.strictEqual(
        document.activeElement,
        firstButton,
        "Shift+Tab reaches the first visible button"
      );
      await tab({ backwards: true });
      assert.strictEqual(
        document.activeElement,
        visibleInput,
        "Shift+Tab wraps to the visible input instead of stalling on the CSS-hidden input"
      );
    });

    test("pointer-oracle: a service menu rendered as a mobile modal exposes its supplied label", async function (assert) {
      forceMobile();

      await render(
        <template>
          <button class="menu-trigger" type="button">Open actions</button>
          <DMenus />
          <ModalContainer />
        </template>
      );

      const expectedLabel = "Pointer actions for the selected item";
      await this.owner.lookup("service:menu").show(find(".menu-trigger"), {
        component: CloseMenu,
        identifier: "pointer-oracle-mobile-menu",
        modalForMobile: true,
        ariaLabel: expectedLabel,
      });
      await settled();

      const dialog =
        '.fk-d-menu-modal[data-identifier="pointer-oracle-mobile-menu"]';
      assert.dom(dialog).exists("the service menu renders in the modal branch");
      assert
        .dom(dialog)
        .hasAttribute("role", "dialog", "the modal is a dialog");
      assert
        .dom(dialog)
        .hasAttribute("aria-modal", "true", "the dialog is modal");
      assert.dom(".fk-d-menu").doesNotExist("no popover menu is rendered");
      assert
        .dom(dialog)
        .hasAttribute(
          "aria-label",
          expectedLabel,
          "the mobile menu dialog exposes the supplied accessible label"
        );

      await click(`${dialog} .close-menu`);
    });
  }
);
