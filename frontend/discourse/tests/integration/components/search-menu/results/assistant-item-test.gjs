import { getOwner } from "@ember/owner";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import AssistantItem from "discourse/components/search-menu/results/assistant-item";
import noop from "discourse/helpers/noop";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { i18n } from "discourse-i18n";

module(
  "Integration | Component | search-menu/results/assistant-item",
  function (hooks) {
    setupRenderingTest(hooks);

    test("renders mobile hint text on mobile devices", async function (assert) {
      const site = getOwner(this).lookup("service:site");
      sinon.stub(site, "mobileView").value(true);

      await render(
        <template>
          <ul>
            <AssistantItem
              @extraHint={{true}}
              @label="test search"
              @closeSearchMenu={{noop}}
              @searchTermChanged={{noop}}
            />
          </ul>
        </template>
      );

      assert.dom(".extra-hint").hasText(i18n("search.mobile_enter_hint"));
    });

    test("renders desktop hint text on desktop devices", async function (assert) {
      const site = getOwner(this).lookup("service:site");
      sinon.stub(site, "mobileView").value(false);

      await render(
        <template>
          <ul>
            <AssistantItem
              @extraHint={{true}}
              @label="test search"
              @closeSearchMenu={{noop}}
              @searchTermChanged={{noop}}
            />
          </ul>
        </template>
      );

      assert.dom(".extra-hint").hasText(i18n("search.enter_hint"));
    });
  }
);
