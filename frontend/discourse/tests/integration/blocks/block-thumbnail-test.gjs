import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import BlockThumbnail from "discourse/blocks/block-thumbnail";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

// A stand-in for a block's inline SVG thumbnail component.
const StubThumbnail = <template>
  <svg class="stub-thumbnail" ...attributes></svg>
</template>;

// A stand-in for a caller-supplied placeholder component. Renders the block's
// icon ID so tests can assert it was forwarded.
const StubFallback = <template>
  <span class="stub-fallback" ...attributes>{{@icon}}</span>
</template>;

module("Integration | Component | blocks/block-thumbnail", function (hooks) {
  setupRenderingTest(hooks);

  test("renders a component thumbnail inline, forwarding the sizing class", async function (assert) {
    await render(
      <template>
        <BlockThumbnail
          @thumbnail={{StubThumbnail}}
          @icon="cube"
          class="sized"
        />
      </template>
    );

    assert
      .dom("svg.stub-thumbnail.sized")
      .exists("the component renders inline and receives the splatted class");
  });

  test("resolves and renders a lazy component thumbnail inline", async function (assert) {
    // A lazily-loaded thumbnail: a loader that resolves to the component.
    const loader = () => Promise.resolve(StubThumbnail);

    await render(
      <template>
        <BlockThumbnail @thumbnail={{loader}} @icon="cube" class="sized" />
      </template>
    );

    assert
      .dom("svg.stub-thumbnail.sized")
      .exists("the resolved component renders inline and receives the class");
  });

  test("unwraps the default export from a lazy loader", async function (assert) {
    // The loader may resolve to a module whose default export is the component
    // (the shape produced by a dynamic import).
    const loader = () => Promise.resolve({ default: StubThumbnail });

    await render(
      <template>
        <BlockThumbnail @thumbnail={{loader}} @icon="cube" class="sized" />
      </template>
    );

    assert
      .dom("svg.stub-thumbnail.sized")
      .exists("the module's default export is rendered inline");
  });

  test("renders the icon when a lazy loader rejects", async function (assert) {
    const loader = () => Promise.reject(new Error("load failed"));

    await render(
      <template>
        <BlockThumbnail @thumbnail={{loader}} @icon="star" class="sized" />
      </template>
    );

    assert
      .dom(".block-thumbnail__icon.sized .d-icon")
      .exists(
        "the block's icon is shown when the loader never yields a component"
      );
    assert.dom("svg.stub-thumbnail").doesNotExist();
  });

  test("renders the @fallback when a lazy loader rejects", async function (assert) {
    const loader = () => Promise.reject(new Error("load failed"));

    await render(
      <template>
        <BlockThumbnail
          @thumbnail={{loader}}
          @icon="star"
          @fallback={{StubFallback}}
          class="sized"
        />
      </template>
    );

    assert
      .dom(".stub-fallback.sized")
      .hasText("star", "the fallback renders, receiving the class and icon ID");
    assert.dom(".block-thumbnail__icon").doesNotExist();
  });

  test("renders a URL string through an image", async function (assert) {
    await render(
      <template>
        <BlockThumbnail
          @thumbnail="/uploads/heading.png"
          @icon="cube"
          class="sized"
        />
      </template>
    );

    assert.dom("img.sized").exists();
    const src = document.querySelector("img.sized").getAttribute("src");
    assert.true(
      src.includes("/uploads/heading.png"),
      "the image points at the declared URL"
    );
  });

  test("renders a light/dark pair, using the light image as the default source", async function (assert) {
    const pair = { light: "/uploads/light.png", dark: "/uploads/dark.png" };

    await render(
      <template>
        <BlockThumbnail @thumbnail={{pair}} @icon="cube" class="sized" />
      </template>
    );

    assert.dom("img.sized").exists("a raster image is rendered");
    const src = document.querySelector("img.sized").getAttribute("src");
    assert.true(
      src.includes("/uploads/light.png"),
      "the light image is the default source"
    );
  });

  test("renders the icon when nothing is declared", async function (assert) {
    await render(
      <template><BlockThumbnail @icon="star" class="sized" /></template>
    );

    assert
      .dom(".block-thumbnail__icon.sized .d-icon")
      .exists("the block's icon is shown as the default placeholder");
  });

  test("renders the @fallback when nothing is declared", async function (assert) {
    await render(
      <template>
        <BlockThumbnail @icon="star" @fallback={{StubFallback}} class="sized" />
      </template>
    );

    assert
      .dom(".stub-fallback.sized")
      .hasText("star", "the fallback renders, receiving the class and icon ID");
    assert.dom(".block-thumbnail__icon").doesNotExist();
  });
});
