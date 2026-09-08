import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import ModalContainer from "discourse/components/modal-container";
import DMenus from "discourse/float-kit/components/d-menus";
import { forceMobile, resetMobile } from "discourse/lib/mobile";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import ChatNavbarChannelListOptionsButton from "discourse/plugins/chat/discourse/components/chat/navbar/channel-list-options-button";

module(
  "Integration | Component | ChatNavbarChannelListOptionsButton",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      resetMobile();
    });

    test("is hidden on desktop because the in-list divider shows the menu", async function (assert) {
      await render(
        <template>
          <ChatNavbarChannelListOptionsButton @section="channels" />
          <DMenus />
        </template>
      );

      assert
        .dom(".chat-channel-list-options-button")
        .doesNotExist("the navbar options button is desktop-hidden");
    });

    test("opens the section's shared options menu on mobile", async function (assert) {
      forceMobile();

      await render(
        <template>
          <ChatNavbarChannelListOptionsButton @section="channels" />
          <DMenus />
          <ModalContainer />
        </template>
      );

      await click(".chat-channel-list-options-button");

      assert
        .dom(
          '.fk-d-menu-modal[data-identifier="chat-channel-list-options-menu"]'
        )
        .exists("the shared options menu opens from the mobile navbar");
      assert
        .dom(".chat-channel-list-options-menu")
        .hasText(
          /Browse channels/,
          "the channels options are shown for the channels section"
        );
    });
  }
);
