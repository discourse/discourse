import { tracked } from "@glimmer/tracking";
import {
  click,
  find,
  render,
  rerender,
  settled,
  triggerEvent,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import { capabilities } from "discourse/services/capabilities";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import DButton from "discourse/ui-kit/d-button";
import DComboButton from "discourse/ui-kit/d-combo-button";
import DEmptyState from "discourse/ui-kit/d-empty-state";
import DPageSubheader from "discourse/ui-kit/d-page-subheader";
import dAvatar from "discourse/ui-kit/helpers/d-avatar";
import dElement from "discourse/ui-kit/helpers/d-element";

module("Integration | ui-kit | ConsumerGapsIndependent", function (hooks) {
  setupRenderingTest(hooks);

  for (const isIOS of [false, true]) {
    for (const immediate of [false, true]) {
      for (const type of ["click", "keydown"]) {
        test(`Independent030eac exact dispatch iOS=${isIOS} immediate=${immediate} ${type}`, async function (assert) {
          sinon.stub(capabilities, "isIOS").get(() => isIOS);
          const calls = [];
          const param = { marker: true };
          const handler = (value, event) =>
            calls.push({ value, event, phase: event.eventPhase });
          await render(
            <template>
              <DButton
                class="independent-button"
                @action={{handler}}
                @actionParam={{param}}
                @forwardEvent={{true}}
                @immediate={{immediate}}
              />
            </template>
          );
          const button = find(".independent-button");
          const event =
            type === "click"
              ? new MouseEvent(type, { bubbles: true, cancelable: true })
              : new KeyboardEvent(type, {
                  key: "Enter",
                  bubbles: true,
                  cancelable: true,
                });
          // Raw dispatch is necessary to observe the boundary before settling.
          button.dispatchEvent(event);
          assert.strictEqual(
            calls.length,
            isIOS || immediate ? 1 : 0,
            "dispatch boundary is observable"
          );
          assert.true(
            event.defaultPrevented,
            "component intercepted the event"
          );
          await settled();
          assert.strictEqual(
            calls.length,
            1,
            "one action, including after settling"
          );
          assert.strictEqual(
            calls[0].event,
            event,
            "the exact original event is forwarded"
          );
          assert.strictEqual(
            calls[0].value,
            param,
            "the original parameter identity is retained"
          );
          assert.strictEqual(
            calls[0].phase,
            isIOS || immediate ? Event.AT_TARGET : Event.NONE,
            "callback runs in the target listener or after dispatch"
          );
        });
      }
    }
  }

  test("Independent030eac custom key handler owns Enter", async function (assert) {
    const handler = sinon.spy();
    const onKeyDown = sinon.spy();
    await render(
      <template>
        <DButton
          @action={{handler}}
          @immediate={{true}}
          @onKeyDown={{onKeyDown}}
        />
      </template>
    );
    const event = new KeyboardEvent("keydown", { key: "Enter", bubbles: true });
    find(".btn").dispatchEvent(event);
    await settled();
    assert.true(
      onKeyDown.calledOnceWithExactly(event),
      "custom handler gets the original event"
    );
    assert.false(handler.called, "Enter does not also invoke the action");
  });

  test("Independent030eac disabled native buttons suppress activation", async function (assert) {
    const handler = sinon.spy();
    await render(
      <template>
        <DButton
          class="disabled"
          @action={{handler}}
          @disabled={{true}}
        /><DButton class="loading" @action={{handler}} @isLoading={{true}} />
      </template>
    );
    assert
      .dom("button.disabled")
      .isDisabled("disabled argument reaches native button");
    assert
      .dom("button.loading")
      .isDisabled("loading disables the native button");
    find("button.disabled").click();
    find("button.loading").click();
    await settled();
    assert.false(handler.called, "native activation is suppressed");
  });

  test("Independent030eac heading identity and link survive title updates", async function (assert) {
    const state = new (class {
      @tracked title = "First";
      @tracked level = 2;
    })();
    await render(
      <template>
        <DPageSubheader
          @titleHeadingLevel={{state.level}}
          @titleLabel={{state.title}}
          @titleUrl="#independent"
        />
      </template>
    );
    const heading = find("h2.d-page-subheader__title");
    const link = find(".d-page-subheader__title-link");
    assert
      .dom(heading)
      .doesNotHaveClass(
        "ember-view",
        "heading shortcut avoids classic component markup"
      );
    assert
      .dom(heading)
      .doesNotHaveAttribute("id", "heading shortcut has no generated id");
    state.title = "Second";
    await rerender();
    assert.strictEqual(
      find("h2.d-page-subheader__title"),
      heading,
      "same-level rerender preserves heading node"
    );
    assert.strictEqual(
      find(".d-page-subheader__title-link"),
      link,
      "same-level rerender preserves linked child"
    );
    assert.dom(link).hasText("Second", "text updates in place");
    for (const level of [1, 3, 4, 5, 6, 2]) {
      state.level = level;
      await rerender();
      assert
        .dom(`h${level}.d-page-subheader__title`)
        .exists({ count: 1 }, "requested heading renders once");
      assert
        .dom(".d-page-subheader__title-link")
        .hasAttribute("href", "#independent", "link survives level change");
    }
  });

  test("Independent030eac heading shortcut forwards attributes and retains identity by tag", async function (assert) {
    const Heading = dElement("h2");
    assert.strictEqual(dElement("h2"), Heading, "stable wrapper identity");
    assert.notStrictEqual(
      dElement("h3"),
      Heading,
      "different tags have different wrappers"
    );
    await render(
      <template>
        <Heading
          id="independent-heading"
          class="consumer-heading"
          aria-label="Accessible title"
        >Body</Heading>
      </template>
    );
    assert
      .dom("h2#independent-heading")
      .hasClass("consumer-heading", "caller class reaches heading");
    assert
      .dom("h2#independent-heading")
      .hasAttribute(
        "aria-label",
        "Accessible title",
        "ARIA attribute reaches heading"
      );
    assert
      .dom("h2#independent-heading")
      .hasText("Body", "no extra wrapper element");
  });

  test("Independent030eac empty state merges dynamic classes and removes image mode", async function (assert) {
    const state = new (class {
      @tracked icon = "gear";
      @tracked extra = "first";
    })();
    await render(
      <template>
        <DEmptyState
          class={{state.extra}}
          id="independent-empty"
          role="status"
          @icon={{state.icon}}
          @identifier="oracle"
          @title="Empty"
        />
      </template>
    );
    assert
      .dom("#independent-empty")
      .hasClass("empty-state__container", "base class survives splat");
    assert
      .dom("#independent-empty")
      .hasClass("--oracle", "identifier survives splat");
    assert
      .dom("#independent-empty")
      .hasClass("--with-image", "icon enables image mode");
    state.icon = null;
    state.extra = "second";
    await rerender();
    assert
      .dom("#independent-empty")
      .hasClass("second", "dynamic consumer class updates");
    assert
      .dom("#independent-empty")
      .doesNotHaveClass("first", "stale consumer class removed");
    assert
      .dom("#independent-empty")
      .hasClass("--text-only", "text mode restored");
    assert
      .dom("#independent-empty")
      .doesNotHaveClass("--with-image", "image mode removed");
    assert
      .dom("#independent-empty")
      .hasAttribute("role", "status", "role forwarded");
    assert.dom(".empty-state__image").doesNotExist("icon removed");
  });

  test("Independent030eac menu close has an inert inside-click control", async function (assert) {
    await render(
      <template>
        <DComboButton @hasMenu={{true}} as |combo|><combo.Button
            @translatedLabel="Main"
          /><combo.Menu
            @inline={{true}}
            @visibilityOptimizer="none"
            as |menu|
          ><DButton class="inert" @translatedLabel="Inert" /><DButton
              class="explicit-close"
              @action={{menu.close}}
              @translatedLabel="Close"
            /></combo.Menu></DComboButton>
      </template>
    );
    await triggerEvent(".fk-d-menu__trigger", "click");
    await click(".inert");
    assert
      .dom(".fk-d-menu")
      .exists("an inside click alone does not close the menu");
    await click(".explicit-close");
    assert.dom(".fk-d-menu").doesNotExist("yielded API closes the menu");
  });

  test("Independent030eac avatar helper separates display name from title and escapes alt", async function (assert) {
    this.siteSettings.prioritize_username_in_ux = false;
    this.siteSettings.enable_names = true;
    const user = {
      username: "login_name",
      name: "O'Name <&>",
      title: "Moderator",
      avatar_template: "/avatar/{size}.png",
    };
    await render(
      <template>
        <div class="named">{{dAvatar user imageSize="tiny" alt=true}}</div><div
          class="decorative"
        >{{dAvatar user imageSize="tiny"}}</div><div class="explicit">{{dAvatar
            user
            imageSize="tiny"
            alt="' onerror='alert(1)"
          }}</div>
      </template>
    );
    assert
      .dom(".named img")
      .hasAttribute("alt", user.name, "alt true uses display name, not title");
    assert
      .dom(".named img")
      .hasAttribute("title", "Moderator", "title remains independent");
    assert
      .dom(".decorative img")
      .hasAttribute("alt", "", "default remains decorative");
    assert
      .dom(".explicit img")
      .hasAttribute(
        "alt",
        "' onerror='alert(1)",
        "single quotes round trip as text"
      );
    assert
      .dom(".explicit img")
      .doesNotHaveAttribute("onerror", "alt cannot create an attribute");
  });
});
