import { click, find, render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import ModalContainer from "discourse/components/modal-container";
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

    // Defect 2: frontend/discourse/float-kit/components/d-float-body.gts:145 emits an id with no label element.
    test("pointer-oracle: an idless service trigger gives the menu a usable label", async function (assert) {
      await render(
        <template>
          <button type="button" class="menu-trigger">Pointer actions</button>
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

    test("pointer-oracle: a service menu rendered as a mobile modal exposes its supplied label", async function (assert) {
      forceMobile();

      await render(
        <template>
          <button type="button" class="menu-trigger">Open actions</button>
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
