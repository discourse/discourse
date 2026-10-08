import { click, findAll, render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import { restoreBaseUri, setPrefix } from "discourse/lib/get-url";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import AiArtifact from "discourse/plugins/discourse-ai/discourse/components/ai-artifact";

module("Integration | Component | AiArtifact", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.siteSettings.ai_artifact_security = "lax";
  });

  hooks.afterEach(() => restoreBaseUri());

  test("uses the share endpoint ahead of source id/version, with site prefix and no eligibility check", async function (assert) {
    setPrefix("/forum");
    this.owner.lookup("service:current-user").can_share_ai_bot_conversations =
      true;

    await render(
      <template>
        <AiArtifact
          @artifactId="12"
          @artifactVersion="3"
          @dataAttributes={{hash data-trace="safe"}}
          @shareKey="key_ABC-123"
        />
      </template>
    );

    assert
      .dom(".ai-artifact__wrapper iframe")
      .hasAttribute(
        "src",
        "/forum/discourse-ai/ai-bot/artifact-shares/key_ABC-123/forum",
        "the native snapshot endpoint wins over a source id and version"
      )
      .hasAttribute("data-trace", "safe", "other metadata reaches the iframe")
      .doesNotHaveAttribute(
        "data-ai-artifact-share-key",
        "the secret is not copied as iframe metadata"
      );
    assert.dom(".ai-artifact-share").doesNotExist("no share probe is mounted");
  });

  test("strict and hybrid retain click-to-run, height, and fullscreen per key", async function (assert) {
    this.siteSettings.ai_artifact_security = "strict";
    await render(
      <template>
        <AiArtifact @artifactHeight="620" @shareKey="first" />
        <AiArtifact @artifactHeight="440" @shareKey="second" />
      </template>
    );
    assert
      .dom(".ai-artifact__wrapper iframe")
      .doesNotExist("strict mode gates execution");
    assert
      .dom(".ai-artifact__wrapper:first-child")
      .hasAttribute("style", /height: 620px/, "height is retained");
    await click(
      ".ai-artifact__wrapper:first-child .ai-artifact__click-to-run button"
    );
    assert
      .dom(".ai-artifact__wrapper iframe")
      .exists({ count: 1 }, "click runs one embed")
      .hasAttribute(
        "src",
        "/discourse-ai/ai-bot/artifact-shares/first/forum",
        "a share key alone loads the native snapshot"
      );
    assert.dom(".ai-artifact-share").doesNotExist("keyed embeds never probe");
    await click(
      ".ai-artifact__wrapper:first-child .ai-artifact__expand-button"
    );
    assert
      .dom(".ai-artifact__expanded")
      .exists({ count: 1 }, "one embed expands");
    window.dispatchEvent(
      new PopStateEvent("popstate", { state: history.state })
    );
    await settled();
    assert
      .dom(".ai-artifact__expanded")
      .exists({ count: 1 }, "history targets only the first key");
    assert.strictEqual(findAll(".ai-artifact__expanded iframe").length, 1);
    history.back();
    await settled();

    this.siteSettings.ai_artifact_security = "hybrid";
    await render(
      <template>
        <AiArtifact @autorun={{true}} @shareKey="third" />
        <AiArtifact @shareKey="fourth" />
      </template>
    );
    assert
      .dom(".ai-artifact__wrapper iframe")
      .exists({ count: 1 }, "hybrid autorun works");
    assert
      .dom(".ai-artifact__click-to-run")
      .exists({ count: 1 }, "hybrid defaults to click");
  });

  test("source versions still render and legacy fullscreen history matches only source embeds", async function (assert) {
    await render(
      <template>
        <AiArtifact @artifactId="12" @artifactVersion="3" />
        <AiArtifact @shareKey="keyed" />
      </template>
    );
    assert
      .dom(".ai-artifact__wrapper:first-child iframe")
      .hasAttribute(
        "src",
        "/discourse-ai/ai-bot/artifacts/12/3",
        "a source version keeps its original endpoint"
      );

    window.dispatchEvent(
      new PopStateEvent("popstate", { state: { artifactId: "12" } })
    );
    await settled();
    assert
      .dom(".ai-artifact__expanded")
      .exists({ count: 1 }, "legacy history expands only the source embed");
    assert
      .dom(".ai-artifact__wrapper:first-child")
      .hasClass("ai-artifact__expanded", "the source owns this history state");
  });

  test("zero and absent versions use the base source URL while positive versions retain their path", async function (assert) {
    await render(
      <template>
        <AiArtifact @artifactId="12" @artifactVersion={{0}} />
        <AiArtifact @artifactId="12" @artifactVersion="0" />
        <AiArtifact @artifactId="12" @artifactVersion="" />
        <AiArtifact @artifactId="12" @artifactVersion={{3}} />
        <AiArtifact @artifactId="12" @artifactVersion="3" />
      </template>
    );

    for (const index of [1, 2, 3]) {
      assert
        .dom(`.ai-artifact__wrapper:nth-child(${index}) iframe`)
        .hasAttribute(
          "src",
          "/discourse-ai/ai-bot/artifacts/12",
          "zero and absent versions load the base source"
        );
    }
    for (const index of [4, 5]) {
      assert
        .dom(`.ai-artifact__wrapper:nth-child(${index}) iframe`)
        .hasAttribute(
          "src",
          "/discourse-ai/ai-bot/artifacts/12/3",
          "positive versions load their source revision"
        );
    }
  });

  test("malformed identifiers never construct source or share URL", async function (assert) {
    const overlongKey = "a".repeat(129);
    await render(
      <template>
        <AiArtifact @artifactId="12" @shareKey={{overlongKey}} />
        <AiArtifact @artifactId="12" @shareKey="../escape" />
        <AiArtifact @artifactId="12" @shareKey="" />
        <AiArtifact @artifactId="https://evil.example" />
        <AiArtifact @artifactId="12" @artifactVersion="../../escape" />
      </template>
    );
    assert
      .dom(".ai-artifact__wrapper iframe")
      .doesNotExist("neither URL is opened");
  });
});
