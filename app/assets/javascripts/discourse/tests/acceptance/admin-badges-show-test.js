import {
  acceptance,
  exists,
  query,
} from "discourse/tests/helpers/qunit-helpers";
import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";

acceptance("Admin - Badges - Show", function (needs) {
  needs.user();
  test("new badge page", async function (assert) {
    await visit("/admin/badges/new");
    assert.ok(
      !query("input#badge-icon").checked,
      "radio button for selecting an icon is off initially"
    );
    assert.ok(
      !query("input#badge-image").checked,
      "radio button for uploading an image is off initially"
    );
    assert.ok(!exists(".icon-picker"), "icon picker is not visible");
    assert.ok(!exists(".image-uploader"), "image uploader is not visible");

    await click("input#badge-icon");
    assert.ok(
      exists(".icon-picker"),
      "icon picker is visible after clicking the select icon radio button"
    );
    assert.ok(!exists(".image-uploader"), "image uploader remains hidden");

    await click("input#badge-image");
    assert.ok(
      !exists(".icon-picker"),
      "icon picker is hidden after clicking the upload image radio button"
    );
    assert.ok(
      exists(".image-uploader"),
      "image uploader becomes visible after clicking the upload image radio button"
    );
  });

  test("existing badge that has an icon", async function (assert) {
    await visit("/admin/badges/1");
    assert.ok(
      query("input#badge-icon").checked,
      "radio button for selecting an icon is on"
    );
    assert.ok(
      !query("input#badge-image").checked,
      "radio button for uploading an image is off"
    );
    assert.ok(exists(".icon-picker"), "icon picker is visible");
    assert.ok(!exists(".image-uploader"), "image uploader is not visible");
    assert.equal(query(".icon-picker").textContent.trim(), "fa-rocket");
  });

  test("existing badge that has an image URL", async function (assert) {
    await visit("/admin/badges/2");
    assert.ok(
      !query("input#badge-icon").checked,
      "radio button for selecting an icon is off"
    );
    assert.ok(
      query("input#badge-image").checked,
      "radio button for uploading an image is on"
    );
    assert.ok(!exists(".icon-picker"), "icon picker is not visible");
    assert.ok(exists(".image-uploader"), "image uploader is visible");
    assert.ok(
      query(".image-uploader a.lightbox").href.endsWith(
        "/assets/some-image.png"
      ),
      "image uploader shows the right image"
    );
  });

  test("existing badge that has both an icon and image URL", async function (assert) {
    await visit("/admin/badges/3");
    assert.ok(
      !query("input#badge-icon").checked,
      "radio button for selecting an icon is off because image overrides icon"
    );
    assert.ok(
      query("input#badge-image").checked,
      "radio button for uploading an image is on because image overrides icon"
    );
    assert.ok(!exists(".icon-picker"), "icon picker is not visible");
    assert.ok(exists(".image-uploader"), "image uploader is visible");
    assert.ok(
      query(".image-uploader a.lightbox").href.endsWith(
        "/assets/some-image.png"
      ),
      "image uploader shows the right image"
    );

    await click("input#badge-icon");
    assert.ok(exists(".icon-picker"), "icon picker is becomes visible");
    assert.ok(!exists(".image-uploader"), "image uploader becomes hidden");
    assert.equal(query(".icon-picker").textContent.trim(), "fa-rocket");
  });
});
