import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import VoiceParticipantSidebarSuffix from "discourse/plugins/voice/discourse/components/voice-participant-sidebar-suffix";

module(
  "Integration | Component | voice-participant-sidebar-suffix",
  function (hooks) {
    setupRenderingTest(hooks);

    test("renders every applicable state icon simultaneously", async function (assert) {
      const suffixArgs = {
        isScreenSharing: true,
        isVideoOn: true,
        isPtt: false,
        isMuted: true,
        isDeafened: true,
      };

      await render(
        <template>
          <VoiceParticipantSidebarSuffix @suffixArgs={{suffixArgs}} />
        </template>
      );

      assert.dom(".voice-participant-suffix .d-icon-display").exists();
      assert.dom(".voice-participant-suffix .d-icon-video").exists();
      assert.dom(".voice-participant-suffix .d-icon-microphone-slash").exists();
      assert.dom(".voice-participant-suffix .d-icon-volume-xmark").exists();
    });

    test("renders the wrapper even with no active states", async function (assert) {
      const suffixArgs = {
        isScreenSharing: false,
        isVideoOn: false,
        isPtt: false,
        isMuted: false,
        isDeafened: false,
      };

      await render(
        <template>
          <VoiceParticipantSidebarSuffix @suffixArgs={{suffixArgs}} />
        </template>
      );

      assert.dom(".voice-participant-suffix").exists();
      assert.dom(".voice-participant-suffix .d-icon").doesNotExist();
    });
  }
);
