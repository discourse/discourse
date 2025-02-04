import { getOwner } from "@ember/owner";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import LightDarkImg from "discourse/components/light-dark-img";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

const lightSrc = { url: "/images/light.jpg", width: 376, height: 500 };
const darkSrc = { url: "/images/light.jpg", width: 432, height: 298 };

module("Integration | Component | light-dark-img", function (hooks) {
  setupRenderingTest(hooks);

  hooks.afterEach(function () {
    this.session = getOwner(this).lookup("service:session");
    this.session.set("darkModeAvailable", null);
    this.session.set("defaultColorSchemeIsDark", null);
  });

  test("light theme with no images provided | dark mode not available", async function (assert) {
    this.session.set("defaultColorSchemeIsDark", false);
    this.session.set("darkModeAvailable", false);

    await render(<template><LightDarkImg /></template>);

    assert.dom("picture").doesNotExist("there is no picture tag");
    assert.dom("img").doesNotExist("there is no img tag");
    assert.dom("source").doesNotExist("there are no source tags");
  });

  test("light theme with only light image provided | dark mode not available", async function (assert) {
    this.session.set("defaultColorSchemeIsDark", false);
    this.session.set("darkModeAvailable", false);

    await render(<template><LightDarkImg @lightImg={{lightSrc}} /></template>);

    assert.dom("picture").doesNotExist("there is no picture tag");
    assert.dom("img").exists("there is an img tag");
    assert
      .dom("img")
      .hasAttribute("src", lightSrc.url, "the img src is the light image");
    assert.dom("source").doesNotExist("there are no source tags");
  });

  test("light theme with light and dark images provided | dark mode not available", async function (assert) {
    this.session.set("defaultColorSchemeIsDark", false);
    this.session.set("darkModeAvailable", false);

    await render(<template>
      <LightDarkImg @lightImg={{lightSrc}} @darkImg={{darkSrc}} />
    </template>);

    assert.dom("picture").doesNotExist("there is no picture tag");
    assert.dom("img").exists("there is an img tag");
    assert
      .dom("img")
      .hasAttribute("src", lightSrc.url, "the img src is the light image");
    assert.dom("source").doesNotExist("there are no source tags");
  });

  test("light theme with no images provided | dark mode available", async function (assert) {
    this.session.set("defaultColorSchemeIsDark", false);
    this.session.set("darkModeAvailable", true);

    await render(<template><LightDarkImg /></template>);

    assert.dom("picture").doesNotExist("there is no picture tag");
    assert.dom("img").doesNotExist("there is no img tag");
    assert.dom("source").doesNotExist("there are no source tags");
  });

  test("light theme with only light image provided | dark mode available", async function (assert) {
    this.session.set("defaultColorSchemeIsDark", false);
    this.session.set("darkModeAvailable", true);

    await render(<template><LightDarkImg @lightImg={{lightSrc}} /></template>);

    assert.dom("picture").doesNotExist("there is no picture tag");
    assert.dom("img").exists("there is an img tag");
    assert
      .dom("img")
      .hasAttribute("src", lightSrc.url, "the img src is the light image");
    assert.dom("source").doesNotExist("there are no source tags");
  });

  test("light theme with light and dark images provided | dark mode available", async function (assert) {
    this.session.set("defaultColorSchemeIsDark", false);
    this.session.set("darkModeAvailable", true);

    await render(<template>
      <LightDarkImg @lightImg={{lightSrc}} @darkImg={{darkSrc}} />
    </template>);

    assert.dom("picture").exists("there is a picture tag");
    assert.dom("img").exists("there is an img tag");
    assert
      .dom("img")
      .hasAttribute("src", lightSrc.url, "the img src is the light image");
    assert.dom("source").exists("there is a source tag");
    assert
      .dom("source")
      .hasAttribute(
        "srcset",
        darkSrc.url,
        "the source srcset is the dark image"
      );
  });

  test("dark theme with no images provided | dark mode not available", async function (assert) {
    this.session.set("defaultColorSchemeIsDark", true);
    this.session.set("darkModeAvailable", false);

    await render(<template><LightDarkImg /></template>);

    assert.dom("picture").doesNotExist("there is no picture tag");
    assert.dom("img").doesNotExist("there is no img tag");
    assert.dom("source").doesNotExist("there are no source tags");
  });

  test("dark theme with only light image provided | dark mode not available", async function (assert) {
    this.session.set("defaultColorSchemeIsDark", true);
    this.session.set("darkModeAvailable", false);

    await render(<template><LightDarkImg @lightImg={{lightSrc}} /></template>);

    assert.dom("picture").doesNotExist("there is no picture tag");
    assert.dom("img").exists("there is an img tag");
    assert
      .dom("img")
      .hasAttribute("src", lightSrc.url, "the img src is the light image");
    assert.dom("source").doesNotExist("there are no source tags");
  });

  test("dark theme with light and dark images provided | dark mode not available", async function (assert) {
    this.session.set("defaultColorSchemeIsDark", true);
    this.session.set("darkModeAvailable", false);

    await render(<template>
      <LightDarkImg @lightImg={{lightSrc}} @darkImg={{darkSrc}} />
    </template>);

    assert.dom("picture").exists("there is a picture tag");
    assert.dom("img").exists("there is an img tag");
    assert
      .dom("img")
      .hasAttribute("src", darkSrc.url, "the img src is the dark image");
    assert.dom("source").exists("there is a source tag");
    assert
      .dom("source")
      .hasAttribute(
        "srcset",
        darkSrc.url,
        "the source srcset is the dark image"
      );
  });

  test("dark theme with no images provided | dark mode available", async function (assert) {
    this.session.set("defaultColorSchemeIsDark", true);
    this.session.set("darkModeAvailable", true);

    await render(<template><LightDarkImg /></template>);

    assert.dom("picture").doesNotExist("there is no picture tag");
    assert.dom("img").doesNotExist("there is no img tag");
    assert.dom("source").doesNotExist("there are no source tags");
  });

  test("dark theme with only light image provided | dark mode available", async function (assert) {
    this.session.set("defaultColorSchemeIsDark", true);
    this.session.set("darkModeAvailable", true);

    await render(<template><LightDarkImg @lightImg={{lightSrc}} /></template>);

    assert.dom("picture").doesNotExist("there is no picture tag");
    assert.dom("img").exists("there is an img tag");
    assert
      .dom("img")
      .hasAttribute("src", lightSrc.url, "the img src is the light image");
    assert.dom("source").doesNotExist("there are no source tags");
  });

  test("dark theme with light and dark images provided | dark mode available", async function (assert) {
    this.session.set("defaultColorSchemeIsDark", true);
    this.session.set("darkModeAvailable", true);

    await render(<template>
      <LightDarkImg @lightImg={{lightSrc}} @darkImg={{darkSrc}} />
    </template>);

    assert.dom("picture").exists("there is a picture tag");
    assert.dom("img").exists("there is an img tag");
    assert
      .dom("img")
      .hasAttribute("src", darkSrc.url, "the img src is the dark image");
    assert.dom("source").exists("there is a source tag");
    assert
      .dom("source")
      .hasAttribute(
        "srcset",
        darkSrc.url,
        "the source srcset is the dark image"
      );
  });
});
