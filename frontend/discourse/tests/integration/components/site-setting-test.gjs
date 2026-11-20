import { getOwner } from "@ember/owner";
import {
  click,
  fillIn,
  render,
  settled,
  triggerEvent,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import SiteSettingComponent from "discourse/admin/components/site-setting";
import ThemeSiteSettingEditor from "discourse/admin/components/theme-site-setting-editor";
import ThemeTranslation from "discourse/admin/components/theme-translation";
import SiteSetting from "discourse/admin/models/site-setting";
import ThemeSettings from "discourse/admin/models/theme-settings";
import ThemeSiteSettings from "discourse/admin/models/theme-site-settings";
import Site from "discourse/models/site";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, {
  parsePostData,
  response,
} from "discourse/tests/helpers/create-pretender";
import dSelect from "discourse/tests/helpers/d-select-helper";
import {
  logIn,
  publishToMessageBus,
  updateCurrentUser,
} from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import { i18n } from "discourse-i18n";

function renderSetting(props) {
  const setting = SiteSetting.create(props);
  return render(
    <template><SiteSettingComponent @setting={{setting}} /></template>
  );
}

module("Integration | Component | SiteSetting", function (hooks) {
  setupRenderingTest(hooks);

  test("plain site settings have no theme anchor", async function (assert) {
    await renderSetting({
      setting: "test_setting",
      value: true,
      type: "bool",
    });

    assert.dom(".setting").doesNotHaveClass("linkable");
    assert.dom(".setting").doesNotHaveAttribute("id");
    assert.dom(".setting-link").doesNotExist();
    assert.dom(".setting-label h3").doesNotHaveAttribute("tabindex");
  });

  test("displays host-list setting value", async function (assert) {
    await renderSetting({
      setting: "blocked_onebox_domains",
      value: "a.com|b.com",
      type: "host_list",
    });

    assert.dom(".formatted-selection").hasText("a.com, b.com");
  });

  test("error response with html_message is rendered as HTML", async function (assert) {
    const message = "<h1>Unable to update site settings</h1>";

    pretender.put("/admin/site_settings/test_setting", () => {
      return response(422, { html_message: true, errors: [message] });
    });

    await renderSetting({
      setting: "test_setting",
      value: "",
      type: "input-setting-string",
    });
    await fillIn(".setting input", "value");
    await click(".setting .d-icon-check");

    assert.dom(".validation-error").includesHtml(message);
  });

  test("error response without html_message is not rendered as HTML", async function (assert) {
    const message = "<h1>Unable to update site settings</h1>";

    pretender.put("/admin/site_settings/test_setting", () => {
      return response(422, { errors: [message] });
    });

    await renderSetting({
      setting: "test_setting",
      value: "",
      type: "input-setting-string",
    });
    await fillIn(".setting input", "value");
    await click(".setting .d-icon-check");

    assert.dom(".validation-error h1").doesNotExist();
  });

  test("error response with html_message discards changes", async function (assert) {
    pretender.put("/admin/site_settings/test_setting", () => {
      return response(422, {
        html_message: true,
        errors: ["<a href='/somewhere'>Fix this</a>"],
      });
    });

    await renderSetting({
      setting: "test_setting",
      value: "original",
      type: "input-setting-string",
    });
    await fillIn(".setting input", "new value");
    await click(".setting .d-icon-check");

    assert.dom(".setting input").hasValue("original");
  });

  test("displays file types list setting", async function (assert) {
    await renderSetting({
      setting: "theme_authorized_extensions",
      value: "jpg|jpeg|png",
      type: "file_types_list",
    });

    assert
      .dom(".form-kit__field .formatted-selection")
      .hasText("jpg, jpeg, png");

    await click(".file-types-list__button.image");

    assert
      .dom(".formatted-selection")
      .hasText("jpg, jpeg, png, gif, heic, heif, webp, avif, svg");
    assert
      .dom(".file-types-list__button.image")
      .isDisabled("nothing is left to add once every image type is allowed");
  });

  test("prevents decimal in integer setting input", async function (assert) {
    await renderSetting({
      setting: "suggested_topics_unread_max_days_old",
      value: "",
      type: "integer",
    });

    const input = document.querySelector("input[type='number']");
    const isPrevented = (key) => {
      const event = new KeyboardEvent("keydown", {
        key,
        bubbles: true,
        cancelable: true,
      });
      input.dispatchEvent(event);
      return event.defaultPrevented;
    };

    assert.true(isPrevented(","), "prevents ,");
    assert.true(isPrevented("."), "prevents .");
    assert.false(isPrevented("9"), "allows 9");
  });

  test("does not consider an integer setting overridden if the value is the same as the default", async function (assert) {
    await renderSetting({
      setting: "suggested_topics_unread_max_days_old",
      value: "99",
      default: "99",
      type: "integer",
    });
    await fillIn("input[type='number']", "90");
    assert.dom("input[type='number']").hasValue("90");
    await fillIn("input[type='number']", "99");
    assert
      .dom("[data-setting='suggested_topics_unread_max_days_old']")
      .hasNoClass("overridden");
  });

  test("integer setting renders its description below the control", async function (assert) {
    await renderSetting({
      setting: "test_int",
      value: "5",
      type: "integer",
      description: "Some helpful text",
    });
    assert.dom(".setting-value .desc").hasText("Some helpful text");
    assert
      .dom(".form-kit__container-description")
      .doesNotExist("the FormKit field does not render its own description");
  });

  test("submitting an unchanged setting does not trigger a save request", async function (assert) {
    let requested = false;
    pretender.put("/admin/site_settings/test_int", () => {
      requested = true;
      return response(200, {});
    });
    pretender.put("/admin/site_settings/bulk_update.json", () => {
      requested = true;
      return response(200, {});
    });

    await renderSetting({
      setting: "test_int",
      value: "5",
      default: "5",
      type: "integer",
    });
    await triggerEvent("form", "submit");

    assert.false(requested);
  });

  test("typing in an integer setting does not remount the input", async function (assert) {
    await renderSetting({
      setting: "test_int",
      value: "5",
      default: "5",
      type: "integer",
    });

    const input = document.querySelector("input[type='number']");
    await fillIn(input, "42");

    assert.strictEqual(document.querySelector("input[type='number']"), input);
    assert.dom(".setting-controls__ok").exists();
  });

  test("clearing an integer setting does not mark it dirty", async function (assert) {
    await renderSetting({
      setting: "test_int",
      value: "5",
      default: "5",
      type: "integer",
    });
    await fillIn("input[type='number']", "");

    assert.dom(".setting-controls__ok").doesNotExist();
  });

  test("cancelling a changed integer setting reverts the input", async function (assert) {
    await renderSetting({
      setting: "test_int",
      value: "90",
      default: "90",
      type: "integer",
    });
    await fillIn("input[type='number']", "50");
    assert.dom("input[type='number']").hasValue("50");
    await click(".setting-controls__cancel");
    assert.dom("input[type='number']").hasValue("90");
  });

  test("resetting an overridden integer setting reverts the input", async function (assert) {
    await renderSetting({
      setting: "test_int",
      value: "50",
      default: "90",
      type: "integer",
    });
    assert.dom("input[type='number']").hasValue("50");
    await click(".setting-controls__undo");
    assert.dom("input[type='number']").hasValue("90");
  });

  test("toggling a bool setting on and saving persists the wire value", async function (assert) {
    let body;
    pretender.put("/admin/site_settings/test_bool", (request) => {
      body = parsePostData(request.requestBody);
      return response(200, {});
    });

    await renderSetting({
      setting: "test_bool",
      value: "false",
      default: "false",
      type: "bool",
    });
    await click("input[type='checkbox']");
    await click(".setting-controls__ok");

    assert.strictEqual(body.test_bool, "true");
  });

  test("rewrites setting links in a bool setting description", async function (assert) {
    logIn(getOwner(this));
    updateCurrentUser({ admin: true });

    await renderSetting({
      setting: "test_bool",
      value: "false",
      type: "bool",
      description:
        '<a class="site-setting-link" href="/admin/site_settings/category/all_results?filter=title" data-setting-name="title" data-setting-area="about">Title</a>',
    });

    assert
      .dom("a.site-setting-link")
      .hasAttribute("href", "/admin/config/about?filter=title");
  });

  test("Input for secret site setting is hidden by default", async function (assert) {
    await renderSetting({
      setting: "test_setting",
      secret: true,
      value: "foo",
    });

    assert.dom(".form-kit__control-password").hasAttribute("type", "password");
    assert
      .dom(".form-kit__control-password")
      .hasAttribute(
        "autocomplete",
        "new-password",
        "does not let password managers autofill credentials"
      );
    assert
      .dom(".setting-toggle-secret")
      .doesNotExist("the control owns the reveal toggle");

    await click(".form-kit__control-password-toggle");
    assert.dom(".form-kit__control-password").hasAttribute("type", "text");
  });

  test("an enum setting renders its preview and keeps it in sync", async function (assert) {
    await renderSetting({
      setting: "tag_style",
      value: "simple",
      type: "enum",
      preview: '<span class="tag-preview">{{value}}</span>',
      valid_values: [
        { name: "Simple", value: "simple" },
        { name: "Box", value: "box" },
      ],
    });

    assert.dom(".preview .tag-preview").hasText("simple");

    await fillIn(".form-kit__control-select", "box");

    assert.dom(".preview .tag-preview").hasText("box");
  });

  test("a category setting selects the stored category", async function (assert) {
    const category = Site.current().categories[0];

    await renderSetting({
      setting: "shared_drafts_category",
      value: String(category.id),
      default: "",
      type: "category",
    });

    assert
      .dom(".category-chooser .selected-name")
      .hasAttribute(
        "data-name",
        category.name,
        "the header names the stored category instead of its id"
      );

    await selectKit(".category-chooser").expand();

    assert
      .dom(`.category-row[data-value="${category.id}"]`)
      .hasClass("is-selected", "the stored category is highlighted");
  });

  test("an unset category setting offers a none option", async function (assert) {
    await renderSetting({
      setting: "shared_drafts_category",
      value: "",
      default: "",
      type: "category",
    });

    assert
      .dom(".category-chooser .selected-name")
      .hasText(
        i18n("category.none"),
        "an unset category setting offers a none option rather than uncategorized"
      );
  });

  test("a disabled tag list setting cannot be edited", async function (assert) {
    await renderSetting({
      setting: "digest_suppress_tags",
      value: "dog",
      default: "",
      type: "tag_list",
      disabled: true,
    });

    assert.dom(".tag-chooser").hasClass("is-disabled");
  });

  test("a group list setting saves the picked groups as a pipe-delimited value", async function (assert) {
    let body;
    pretender.put("/admin/site_settings/test_groups", (request) => {
      body = parsePostData(request.requestBody);
      return response(200, {});
    });

    await renderSetting({
      setting: "test_groups",
      value: "1",
      type: "group_list",
    });

    const groups = selectKit(".form-kit__field .list-setting");
    await groups.expand();
    await groups.selectRowByValue("2");
    await click(".setting-controls__ok");

    assert.strictEqual(body.test_groups, "1|2");
  });

  test("a compact list setting saves the picked choices as a pipe-delimited value", async function (assert) {
    let body;
    pretender.put("/admin/site_settings/test_list", (request) => {
      body = parsePostData(request.requestBody);
      return response(200, {});
    });

    await renderSetting({
      setting: "test_list",
      value: "a",
      type: "list",
      list_type: "compact",
      choices: ["a", "b"],
    });

    const list = selectKit(".form-kit__field .list-setting");
    await list.expand();
    await list.selectRowByValue("b");
    await click(".setting-controls__ok");

    assert.strictEqual(body.test_list, "a|b");
  });

  test("a category list setting saves an emptied selection", async function (assert) {
    let body;
    pretender.put("/admin/site_settings/test_categories", (request) => {
      body = parsePostData(request.requestBody);
      return response(200, {});
    });
    const categoryId = Site.current().categories[0].id;

    await renderSetting({
      setting: "test_categories",
      value: String(categoryId),
      type: "category_list",
    });

    const categories = selectKit(".form-kit__field .category-selector");
    await categories.expand();
    await categories.deselectItemByValue(categoryId);
    await click(".setting-controls__ok");

    assert.strictEqual(body.test_categories, "");
  });

  for (const [type, saved] of [
    ["list", "a|b"],
    ["value_list", "a\nb"],
    ["url_list", "a\nb"],
  ]) {
    test(`a ${type} setting saves the added value in its wire format`, async function (assert) {
      let body;
      pretender.put("/admin/site_settings/test_values", (request) => {
        body = parsePostData(request.requestBody);
        return response(200, {});
      });

      await renderSetting({ setting: "test_values", value: "a", type });

      const adder = selectKit(".form-kit__field .value-list .select-kit");
      await adder.expand();
      await adder.fillInFilter("b");
      await adder.keyboard("Enter");
      await click(".setting-controls__ok");

      assert.strictEqual(body.test_values, saved);
    });
  }

  test("a simple list setting saves the typed values as a pipe-delimited value", async function (assert) {
    let body;
    pretender.put("/admin/site_settings/test_simple", (request) => {
      body = parsePostData(request.requestBody);
      return response(200, {});
    });

    await renderSetting({
      setting: "test_simple",
      value: "a",
      type: "list",
      list_type: "simple",
    });

    await fillIn(".form-kit__field .add-value-input", "b");
    await click(".form-kit__field .add-value-btn");
    await click(".setting-controls__ok");

    assert.strictEqual(body.test_simple, "a|b");
  });

  test("an emoji list setting saves the remaining emojis as a pipe-delimited value", async function (assert) {
    let body;
    pretender.put("/admin/site_settings/test_emojis", (request) => {
      body = parsePostData(request.requestBody);
      return response(200, {});
    });

    await renderSetting({
      setting: "test_emojis",
      value: "smile|heart",
      type: "list",
      list_type: "emoji",
    });

    await click(
      ".form-kit__field .emoji-value-list .value[data-index='0'] .remove-value-btn"
    );
    await click(".setting-controls__ok");

    assert.strictEqual(body.test_emojis, "heart");
  });

  test("a secret list setting saves key and secret pairs", async function (assert) {
    let body;
    pretender.put("/admin/site_settings/test_secrets", (request) => {
      body = parsePostData(request.requestBody);
      return response(200, {});
    });

    await renderSetting({
      setting: "test_secrets",
      value: "k1|s1",
      type: "list",
      list_type: "secret",
    });

    await fillIn(".form-kit__field .new-value-input.key", "k2");
    await fillIn(".form-kit__field .new-value-input.secret", "s2");
    await click(".form-kit__field .add-value-btn");
    await click(".setting-controls__ok");

    assert.strictEqual(body.test_secrets, "k1|s1\nk2|s2");
  });

  test("a secret list setting masks its secrets and reports invalid input", async function (assert) {
    await renderSetting({
      setting: "test_secrets",
      value: "k1|s1",
      type: "list",
      list_type: "secret",
      secret: true,
    });

    assert.dom(".form-kit__control-password").doesNotExist();
    assert
      .dom(".value[data-index='0'] .secret")
      .hasAttribute("type", "password");
    assert.dom(".new-value-input.secret").hasAttribute("type", "password");

    await click(".value[data-index='0'] .secret-value-list__reveal");

    assert
      .dom(".value[data-index='0'] .secret")
      .hasAttribute("type", "text", "the toggle reveals its own row");
    assert
      .dom(".new-value-input.secret")
      .hasAttribute("type", "password", "other rows stay masked");

    await click(".form-kit__field .add-value-btn");

    assert
      .dom(".form-kit__field .form-kit__errors")
      .hasText(i18n("admin.site_settings.secret_list.invalid_input"));

    await fillIn(".form-kit__field .new-value-input.key", "k1");
    await fillIn(".form-kit__field .new-value-input.secret", "s2");
    await click(".form-kit__field .add-value-btn");

    assert
      .dom(".form-kit__field .form-kit__errors")
      .hasText(
        i18n("admin.site_settings.secret_list.already_exists", { key: "k1" }),
        "a new rejection replaces the previous message"
      );
  });

  test("a secret list setting shows its key and value placeholders", async function (assert) {
    await renderSetting({
      setting: "test_secrets",
      value: "",
      type: "list",
      list_type: "secret",
      placeholder: { key: "www.example.com", value: "a secret" },
    });

    assert
      .dom(".form-kit__field .new-value-input.key")
      .hasAttribute("placeholder", "www.example.com");
    assert
      .dom(".form-kit__field .new-value-input.secret")
      .hasAttribute("placeholder", "a secret");
  });

  test("cancelling a secret list setting clears its invalid input error", async function (assert) {
    await renderSetting({
      setting: "test_secrets",
      value: "k1|s1",
      type: "list",
      list_type: "secret",
    });

    await click(".form-kit__field .remove-value-btn");
    await click(".form-kit__field .add-value-btn");

    assert.dom(".form-kit__field .form-kit__errors").exists();

    await click(".setting-controls__cancel");

    assert.dom(".form-kit__field .form-kit__errors").doesNotExist();
  });

  test("a file types list setting adds default types to an empty value", async function (assert) {
    let body;
    pretender.put("/admin/site_settings/test_types", (request) => {
      body = parsePostData(request.requestBody);
      return response(200, {});
    });

    await renderSetting({
      setting: "test_types",
      value: "",
      type: "file_types_list",
    });

    assert
      .dom(".form-kit__control-custom > .file-types-list__button")
      .doesNotExist("the buttons are not stretched as direct control children");
    assert.dom(".file-types-list > .file-types-list__button").exists();

    await click(".form-kit__field .file-types-list__button.video");
    await click(".setting-controls__ok");

    assert.strictEqual(body.test_types, "mov|mp4|webm|m4v|3gp|ogv|avi|mpeg");
  });

  test("a file types list setting picks its types with the new select controls", async function (assert) {
    this.siteSettings.enable_new_select_controls = true;
    let body;
    pretender.put("/admin/site_settings/test_types", (request) => {
      body = parsePostData(request.requestBody);
      return response(200, {});
    });

    await renderSetting({
      setting: "test_types",
      value: "jpg|png",
      type: "file_types_list",
    });

    const control = ".form-kit__field .file-types-list .d-select";
    assert.dom(control).hasAttribute("data-name", "jpg,png");
    assert
      .dom(`${control} [role='combobox']`)
      .hasAria("label", "test_types", "the picker is named after the setting");

    assert
      .dom(".file-types-list > .file-types-list__button")
      .doesNotExist("the add-types buttons aren't drawn under the field");

    await dSelect(control).search("mp3");
    await click("[role='option'].--create");

    const buttons = ".d-select__footer .file-types-list__buttons";
    const labelId = document
      .querySelector(buttons)
      ?.getAttribute("aria-labelledby");
    assert
      .dom(buttons)
      .hasAttribute("role", "group", "the add-types buttons form a group");
    assert
      .dom(labelId ? `#${labelId}` : ".no-label")
      .hasText(
        i18n("admin.site_settings.file_types_list.add_common_types"),
        "named by the label drawn before them"
      );

    await click(".d-select__footer .file-types-list__button.document");
    assert
      .dom(control)
      .hasAttribute(
        "data-name",
        "jpg,png,mp3,txt,pdf,doc,docx,csv",
        "a typed type and the default document types join the list"
      );

    await click(".setting-controls__ok");
    assert.strictEqual(body.test_types, "jpg|png|mp3|txt|pdf|doc|docx|csv");
  });

  test("a file types list setting only offers the default types it would add with the new select controls", async function (assert) {
    this.siteSettings.enable_new_select_controls = true;

    await renderSetting({
      setting: "test_types",
      value: "gif|png|jpeg|jpg|heic|heif|webp|avif|svg|mp4",
      type: "file_types_list",
    });

    const control = ".form-kit__field .file-types-list .d-select";
    const images = ".d-select__footer .file-types-list__button.image";
    const videos = ".d-select__footer .file-types-list__button.video";
    await dSelect(control).open();

    assert
      .dom(images)
      .isDisabled("every image type is allowed already")
      .hasAttribute(
        "title",
        i18n("admin.site_settings.file_types_list.already_allowed", {
          types: "gif, png, jpeg, jpg, heic, heif, webp, avif, svg",
        }),
        "and the title says so"
      );
    assert
      .dom(videos)
      .isEnabled("some video types are missing")
      .hasAttribute(
        "title",
        i18n("admin.site_settings.file_types_list.add_types_title", {
          types: "mov, webm, m4v, 3gp, ogv, avi, mpeg",
        }),
        "and the title lists only those"
      );

    await click("[role='option'][data-value='png']");

    assert
      .dom(images)
      .isEnabled("removing an image type offers it again")
      .hasAttribute(
        "title",
        i18n("admin.site_settings.file_types_list.add_types_title", {
          types: "png",
        })
      );
  });

  test("a disabled file types list setting disables its add-types buttons", async function (assert) {
    await renderSetting({
      setting: "test_types",
      value: "jpg",
      type: "file_types_list",
      disabled: true,
    });

    assert
      .dom(".form-kit__field .file-types-list__button.video")
      .isDisabled("even when it would add types");
  });

  test("a disabled file types list setting can't be changed with the new select controls", async function (assert) {
    this.siteSettings.enable_new_select_controls = true;

    await renderSetting({
      setting: "test_types",
      value: "jpg",
      type: "file_types_list",
      disabled: true,
    });

    assert
      .dom(".form-kit__field .file-types-list .d-select [role='combobox']")
      .isDisabled("the picker follows the setting");
    assert
      .dom(".file-types-list__button")
      .doesNotExist(
        "the add-types buttons stay in the panel, which can't open"
      );
  });

  test("an enum setting whose default is blank can be cleared with the new select controls", async function (assert) {
    this.siteSettings.enable_new_select_controls = true;
    let body;
    pretender.put("/admin/site_settings/onebox_locale", (request) => {
      body = parsePostData(request.requestBody);
      return response(200, {});
    });

    await renderSetting({
      setting: "onebox_locale",
      type: "enum",
      value: "fr",
      default: "",
      valid_values: [
        { name: "English", value: "en" },
        { name: "French", value: "fr" },
      ],
    });

    await dSelect(".form-kit__field .d-select").clear();
    await click(".setting-controls__ok");
    assert.strictEqual(body.onebox_locale, "", "saves the blank default");
  });

  test("an upload setting shows its restrictions and saves a removed file", async function (assert) {
    let body;
    pretender.put("/admin/site_settings/test_upload", (request) => {
      body = parsePostData(request.requestBody);
      return response(200, {});
    });

    await renderSetting({
      setting: "test_upload",
      value: "/uploads/default/original/1X/notes.txt",
      type: "upload",
      authorized_extensions: "txt",
      max_file_size_kb: 512,
      upload: { original_filename: "notes.txt", human_filesize: "4 KB" },
    });

    assert.dom(".form-kit__field .file-name").hasText("notes.txt");
    assert.dom(".form-kit__field .file-size").hasText("4 KB");
    assert
      .dom(".form-kit__field .file-uploader__restrictions")
      .includesText(".txt")
      .includesText("512 KB");

    await click(".form-kit__field .file-uploader .btn-danger");
    await click(".setting-controls__ok");

    assert.strictEqual(body.test_upload, "");
  });

  test("an uploaded image list setting saves the images kept in its modal", async function (assert) {
    let body;
    pretender.put("/admin/site_settings/selectable_avatars", (request) => {
      body = parsePostData(request.requestBody);
      return response(200, {});
    });
    const modal = getOwner(this).lookup("service:modal");
    const show = sinon.stub(modal, "show");

    await renderSetting({
      setting: "selectable_avatars",
      value: "/a.png|/b.png",
      type: "uploaded_image_list",
    });

    await click(".form-kit__field button");

    const { model } = show.firstCall.args[1];

    assert.strictEqual(model.value, "/a.png|/b.png");

    model.changeValue("/b.png");
    await settled();
    await click(".setting-controls__ok");

    assert.strictEqual(body.selectable_avatars, "/b.png");
  });

  test("a color setting saves the typed hex with its prefix", async function (assert) {
    let body;
    pretender.put("/admin/site_settings/test_color", (request) => {
      body = parsePostData(request.requestBody);
      return response(200, {});
    });

    await renderSetting({
      setting: "test_color",
      value: "#006699",
      type: "color",
    });

    assert.dom(".form-kit__control-color-input-hex").hasValue("006699");

    await fillIn(".form-kit__control-color-input-hex", "ff0000");
    await click(".setting-controls__ok");

    assert.strictEqual(body.test_color, "#ff0000");

    await fillIn(".form-kit__control-color-input-hex", "red");
    await click(".setting-controls__ok");

    assert.strictEqual(
      body.test_color,
      "red",
      "named colors are kept as typed"
    );
  });

  test("a color list setting saves its colors in order with the new select controls", async function (assert) {
    this.siteSettings.enable_new_select_controls = true;
    let body;
    pretender.put("/admin/site_settings/test_colors", (request) => {
      body = parsePostData(request.requestBody);
      return response(200, {});
    });

    await renderSetting({
      setting: "test_colors",
      value: "FF0000|00FF00",
      default: "",
      type: "list",
      list_type: "color",
    });

    await fillIn(".color-list__add .d-color-input__hex", "0000ff");
    await click(".color-list__add-btn");
    await click(".setting-controls__ok");

    assert.strictEqual(body.test_colors, "FF0000|00FF00|0000FF");
  });

  test("a locale list setting names its choices from the available locales", async function (assert) {
    let body;
    pretender.put("/admin/site_settings/test_locales", (request) => {
      body = parsePostData(request.requestBody);
      return response(200, {});
    });
    this.siteSettings.available_locales = [
      { value: "en", name: "English" },
      { value: "fr", name: "Français" },
    ];

    await renderSetting({
      setting: "test_locales",
      value: "en",
      type: "list",
      list_type: "locale",
      valid_values: [
        { value: "en", name: "en" },
        { value: "fr", name: "fr" },
      ],
    });

    const locales = selectKit(".form-kit__field .list-setting");
    await locales.expand();

    assert.strictEqual(locales.rowByValue("fr").name(), "Français");

    await locales.selectRowByValue("fr");
    await click(".setting-controls__ok");

    assert.strictEqual(body.test_locales, "en|fr");
  });

  test("a topic setting shows the saved topic", async function (assert) {
    await renderSetting({
      setting: "test_topic",
      value: "280",
      type: "topic",
    });

    assert
      .dom(".form-kit__field .topic-chooser .select-kit-header")
      .includesText("Internationalization / localization");
  });

  test("a topic setting saves the picked topic id", async function (assert) {
    let body;
    pretender.put("/admin/site_settings/test_topic", (request) => {
      body = parsePostData(request.requestBody);
      return response(200, {});
    });
    pretender.get("/search/query", () =>
      response({
        topics: [{ id: 42, title: "Moderator guide" }],
        posts: [{ id: 1, topic_id: 42 }],
      })
    );

    await renderSetting({
      setting: "test_topic",
      value: "",
      type: "topic",
    });

    const topics = selectKit(".form-kit__field .topic-chooser");
    await topics.expand();
    await topics.fillInFilter("guide");
    await topics.selectRowByValue(42);
    await click(".setting-controls__ok");

    assert.strictEqual(body.test_topic, "42");
  });

  test("a datetime setting saves the local time as UTC", async function (assert) {
    let body;
    pretender.put("/admin/site_settings/test_datetime", (request) => {
      body = parsePostData(request.requestBody);
      return response(200, {});
    });
    const savedTime = "2026-01-15T10:00:00Z";
    const pickedLocalTime = "2026-02-01T08:30";

    await renderSetting({
      setting: "test_datetime",
      value: savedTime,
      type: "datetime",
    });

    assert
      .dom(".form-kit__field input[type='datetime-local']")
      .hasValue(
        moment(savedTime).local().format(moment.HTML5_FMT.DATETIME_LOCAL)
      );

    await fillIn(
      ".form-kit__field input[type='datetime-local']",
      pickedLocalTime
    );
    await click(".setting-controls__ok");

    assert.strictEqual(
      body.test_datetime,
      moment(pickedLocalTime).utc().format()
    );
  });

  test("a date setting saves the picked date", async function (assert) {
    let body;
    pretender.put("/admin/site_settings/test_date", (request) => {
      body = parsePostData(request.requestBody);
      return response(200, {});
    });

    await renderSetting({
      setting: "test_date",
      value: "",
      type: "date",
    });
    await fillIn(".form-kit__field input[type='date']", "2026-01-15");
    await click(".setting-controls__ok");

    assert.strictEqual(body.test_date, "2026-01-15");
  });

  for (const [type, selector, saved, shown] of [
    ["date", "input[type='date']", "2026-01-15", "2026-01-15"],
    [
      "datetime",
      "input[type='datetime-local']",
      "2026-01-15T10:00:00Z",
      moment("2026-01-15T10:00:00Z")
        .local()
        .format(moment.HTML5_FMT.DATETIME_LOCAL),
    ],
  ]) {
    test(`a ${type} setting can be emptied, then reset to a non-empty default`, async function (assert) {
      let body;
      pretender.put("/admin/site_settings/test_when", (request) => {
        body = parsePostData(request.requestBody);
        return response(200, {});
      });
      const input = `.form-kit__field ${selector}`;

      await renderSetting({
        setting: "test_when",
        value: saved,
        default: saved,
        type,
      });

      await fillIn(input, "");
      await click(".setting-controls__ok");

      assert.strictEqual(body.test_when, "", "saves the emptied value");
      assert.dom(input).hasValue("");

      await click(".setting-controls__undo");

      assert.dom(input).hasValue(shown, "reset restores the default");

      await click(".setting-controls__ok");

      assert.strictEqual(body.test_when, saved);
    });
  }

  test("a secret setting that is also a textarea stays readable", async function (assert) {
    await renderSetting({
      setting: "test_setting",
      secret: true,
      textarea: true,
      value: "-----BEGIN PRIVATE KEY-----",
    });

    assert.dom(".form-kit__control-textarea").exists();
    assert.dom(".form-kit__control-password").doesNotExist();
  });

  test("shows link to the staff action logs for the setting on hover", async function (assert) {
    await renderSetting({
      setting: "enable_badges",
      value: "false",
      default: "true",
      type: "bool",
    });

    await triggerEvent("[data-setting='enable_badges']", "mouseenter");

    assert
      .dom("[data-setting='enable_badges'] .staff-action-log-link")
      .exists()
      .hasAttribute(
        "href",
        `/admin/logs/staff_action_logs?filters=${encodeURIComponent(JSON.stringify({ subject: "enable_badges", action_name: "change_site_setting" }))}&force_refresh=true`
      );
  });

  test("Shows update status for default_categories_* site settings", async function (assert) {
    await renderSetting({
      setting: "default_categories_test",
      value: "",
      type: "category_list",
    });

    await publishToMessageBus("/site_setting/default_categories_test/process", {
      status: "enqueued",
    });

    assert.dom(".desc.site-setting").hasTextContaining("Update in progress");

    await publishToMessageBus("/site_setting/default_categories_test/process", {
      status: "enqueued",
      progress: "10/100",
    });

    assert.dom(".desc.site-setting").hasTextContaining("Update in progress");
    assert.dom(".desc.site-setting").hasTextContaining("10/100");

    await publishToMessageBus("/site_setting/default_categories_test/process", {
      status: "completed",
    });
    assert.dom(".desc.site-setting").hasTextContaining("Update completed");
  });

  test("Shows update status for default_tags_* site settings", async function (assert) {
    await renderSetting({
      setting: "default_tags_test",
      value: "",
      type: "tag_list",
    });

    await publishToMessageBus("/site_setting/default_tags_test/process", {
      status: "enqueued",
    });
    assert.dom(".desc.site-setting").hasTextContaining("Update in progress");

    await publishToMessageBus("/site_setting/default_tags_test/process", {
      status: "enqueued",
      progress: "10/100",
    });

    assert.dom(".desc.site-setting").hasTextContaining("Update in progress");
    assert.dom(".desc.site-setting").hasTextContaining("10/100");

    await publishToMessageBus("/site_setting/default_tags_test/process", {
      status: "completed",
    });
    assert.dom(".desc.site-setting").hasTextContaining("Update completed");
  });

  test("Doesn't shows update status for other site settings besides default_tags_test or default_categories_test", async function (assert) {
    await renderSetting({
      setting: "default_test",
      value: "",
      type: "tag_list",
    });

    await publishToMessageBus("/site_setting/default_tags_test/process", {
      status: "enqueued",
    });
    assert.dom(".desc.site-setting").doesNotExist();

    await publishToMessageBus("/site_setting/default_tags_test/process", {
      status: "completed",
    });
    assert.dom(".desc.site-setting").doesNotExist();
  });

  test("doesn't listen for job progress on unrelated settings", async function (assert) {
    await renderSetting({
      setting: "title",
      value: "",
      type: "string",
    });

    await publishToMessageBus("/site_setting/title/process", {
      status: "enqueued",
    });

    assert.dom(".desc.site-setting").doesNotExist();
  });

  test("theme rows don't register in the site setting change tracker", async function (assert) {
    const tracker = this.owner.lookup("service:site-setting-change-tracker");

    const themeSetting = ThemeSiteSettings.create({
      setting: "enable_welcome_banner",
      value: "true",
      default: "true",
      type: "bool",
    });
    this.themeSetting = themeSetting;
    this.theme = { id: 1, name: "Horizon" };

    await render(
      <template>
        <ThemeSiteSettingEditor
          @model={{this.theme}}
          @setting={{this.themeSetting}}
        />
      </template>
    );

    themeSetting.buffered.set("value", "false");
    await settled();

    assert
      .dom(".setting-controls .ok")
      .exists("the row itself still shows its save button");
    assert.strictEqual(
      tracker.count,
      0,
      "the dirty theme setting is not picked up by the site settings banner"
    );
  });

  test("renders theme translation rows without a setting name", async function (assert) {
    const translation = ThemeSettings.create({
      key: "theme_metadata.description",
      value: "A theme",
      default: "A theme",
      textarea: true,
    });
    this.translation = translation;
    this.theme = { id: 1, locale: "en" };

    await render(
      <template>
        <ThemeTranslation
          @model={{this.theme}}
          @translation={{this.translation}}
        />
      </template>
    );

    assert.dom(".setting textarea").hasValue("A theme");
  });

  test("doesn't display the save/cancel buttons when the selected value is returned to the current value", async function (assert) {
    await renderSetting({
      setting: "some_enum",
      value: "2",
      default: "1",
      type: "enum",
      valid_values: [
        { name: "Option 1", value: 1 },
        { name: "Option 2", value: 2 },
      ],
    });

    await fillIn(".form-kit__control-select", "1");

    assert
      .dom(".setting-controls__ok")
      .exists("the save button is shown after changing the value");
    assert
      .dom(".setting-controls__cancel")
      .exists("the cancel button is shown after changing the value");

    await fillIn(".form-kit__control-select", "2");

    assert
      .dom(".setting-controls__ok")
      .doesNotExist(
        "the save button is not shown after changing the value back to the original"
      );
    assert
      .dom(".setting-controls__cancel")
      .doesNotExist(
        "the cancel button is not shown after changing the value back to the original"
      );
  });
});

module(
  "Integration | Component | SiteSetting | Themeable Settings",
  function (hooks) {
    setupRenderingTest(hooks);

    test("disables input for themeable site settings", async function (assert) {
      this.site = this.container.lookup("service:site");
      this.site.set("user_themes", [
        { theme_id: 5, default: true, name: "Default Theme" },
      ]);

      await renderSetting({
        setting: "test_themeable_setting",
        value: "test value",
        type: "string",
        themeable: true,
      });

      assert.dom(".form-kit__control-input").hasAttribute("disabled", "");
      assert
        .dom(".setting-controls__ok")
        .doesNotExist("save button is not shown");
    });

    test("shows warning text for themeable site settings", async function (assert) {
      this.site = this.container.lookup("service:site");
      this.site.set("user_themes", [
        { theme_id: 5, default: true, name: "Default Theme" },
      ]);

      await renderSetting({
        setting: "test_themeable_setting",
        value: "test value",
        type: "string",
        themeable: true,
      });

      assert
        .dom(".setting-theme-warning")
        .exists("warning wrapper is displayed");

      assert
        .dom(".setting-theme-warning__text")
        .exists("warning text element is displayed");

      const expectedText = i18n(
        "admin.theme_site_settings.site_setting_warning",
        {
          basePath: "",
          defaultThemeName: "Default Theme",
          defaultThemeId: 5,
        }
      );

      assert.dom(".setting-theme-warning__text").includesHtml(expectedText);
    });

    test("shows notice for settings that depend on another setting", async function (assert) {
      await renderSetting({
        setting: "dependent_setting",
        value: "1",
        type: "integer",
        depends_on: ["parent_setting"],
        depends_on_humanized_names: ["Parent setting"],
      });

      assert
        .dom(".setting-depends-on-notice")
        .exists("notice wrapper is displayed");
      assert
        .dom(".setting-depends-on-notice__text")
        .includesText(
          "This setting is only applied when Parent setting is enabled"
        );
      assert
        .dom(".setting-depends-on-notice__text a")
        .hasAttribute(
          "href",
          "/admin/site_settings/category/all_results?filter=parent_setting"
        )
        .hasText("Parent setting");
    });

    test("uses value-based copy for settings that depend on another setting's value", async function (assert) {
      await renderSetting({
        setting: "dependent_setting",
        value: "1",
        type: "integer",
        depends_on: ["parent_setting"],
        depends_on_humanized_names: ["Parent setting"],
        depends_on_values: { parent_setting: ["include"] },
      });

      assert
        .dom(".setting-depends-on-notice__text")
        .includesText(
          "This setting only applies when Parent setting is set to a compatible value."
        );
    });

    test("does not show the depends_on notice when setting has no dependencies", async function (assert) {
      await renderSetting({
        setting: "plain_setting",
        value: "1",
        type: "integer",
      });

      assert.dom(".setting-depends-on-notice").doesNotExist();
    });
  }
);

module(
  "Integration | Component | SiteSetting | file_size_restriction type",
  function (hooks) {
    setupRenderingTest(hooks);

    function renderMaxImageSizeSetting(value) {
      return renderSetting({
        setting: "max_image_size_kb",
        value,
        default: "1024",
        min: 512,
        max: 4096,
        type: "file_size_restriction",
      });
    }

    test("shows the reset button when the value has been changed from the default", async function (assert) {
      await renderMaxImageSizeSetting("2048");
      assert.dom(".setting-controls__undo").exists("reset button is shown");
    });

    test("doesn't show the reset button when the value is the same as the default", async function (assert) {
      await renderMaxImageSizeSetting("1024");
      assert
        .dom(".setting-controls__undo")
        .doesNotExist("reset button is not shown");
    });

    test("shows validation error when the value exceeds the max limit", async function (assert) {
      await renderMaxImageSizeSetting("1024");
      await fillIn(".file-size-input", "5000");

      assert.dom(".form-kit__errors").hasText(
        i18n("file_size_input.error.size_too_large", {
          provided_file_size: "4.9 GB",
          max_file_size: "4 MB",
        }),
        "validation error message is shown"
      );
      assert.dom(".setting-controls__cancel").doesNotHaveAttribute("disabled");
    });

    test("shows validation error when the value is below the min limit", async function (assert) {
      await renderMaxImageSizeSetting("1000");
      await fillIn(".file-size-input", "100");

      assert.dom(".form-kit__errors").hasText(
        i18n("file_size_input.error.size_too_small", {
          provided_file_size: "100 KB",
          min_file_size: "512 KB",
        }),
        "validation error message is shown"
      );
      assert.dom(".setting-controls__cancel").doesNotHaveAttribute("disabled");
    });

    test("cancelling pending changes resets the value and removes validation error", async function (assert) {
      await renderMaxImageSizeSetting("1000");

      await fillIn(".file-size-input", "100");
      assert.dom(".form-kit__errors").exists();

      await click(".setting-controls__cancel");
      assert
        .dom(".file-size-input")
        .hasValue("1000", "the value resets to the saved value");
      assert.dom(".form-kit__errors").doesNotExist();

      await fillIn(".file-size-input", "");
      assert
        .dom(".form-kit__errors")
        .doesNotExist("the cancelled error does not come back");
    });

    test("resetting to the default value changes the content of input field", async function (assert) {
      await renderMaxImageSizeSetting("1000");
      assert
        .dom(".file-size-input")
        .hasValue("1000", "the input field contains the custom value");

      await click(".setting-controls__undo");
      assert
        .dom(".file-size-input")
        .hasValue("1024", "the input field now contains the default value");

      assert
        .dom(".setting-controls__undo")
        .doesNotExist("the reset button is not shown");
      assert.dom(".setting-controls__ok").exists("the save button is shown");
      assert
        .dom(".setting-controls__cancel")
        .exists("the cancel button is shown");
    });

    test("resetting to the default value changes the content of checkbox field", async function (assert) {
      await renderSetting({
        setting: "test_setting",
        value: "true",
        default: "false",
        type: "bool",
      });
      assert
        .dom("input[type=checkbox]")
        .isChecked("the checkbox contains the custom value");

      await click(".setting-controls__undo");
      assert
        .dom("input[type=checkbox]")
        .isNotChecked("the checkbox now contains the default value");

      assert
        .dom(".setting-controls__undo")
        .doesNotExist("the reset button is not shown");
      assert.dom(".setting-controls__ok").exists("the save button is shown");
      assert
        .dom(".setting-controls__cancel")
        .exists("the cancel button is shown");
    });

    test("clearing the input field keeps the cancel button and the validation error shown", async function (assert) {
      await renderMaxImageSizeSetting("1000");

      await fillIn(".file-size-input", "100");
      assert.dom(".form-kit__errors").exists();

      await fillIn(".file-size-input", "");
      assert.dom(".form-kit__errors").exists();
      assert.dom(".setting-controls__ok").exists("the save button is shown");
      assert
        .dom(".setting-controls__cancel")
        .exists("the cancel button is shown");
      assert.dom(".setting-controls__cancel").doesNotHaveAttribute("disabled");

      await click(".setting-controls__cancel");
      assert.dom(".file-size-input").hasValue("1000");
      assert.dom(".form-kit__errors").doesNotExist();
      assert
        .dom(".setting-controls__ok")
        .doesNotExist("the save button is not shown");
      assert
        .dom(".setting-controls__cancel")
        .doesNotExist("the cancel button is shown");
    });
  }
);

module(
  "Integration | Component | SiteSetting | font-list type",
  function (hooks) {
    setupRenderingTest(hooks);

    const fonts = [
      { value: "arial", name: "Arial" },
      { value: "times_new_roman", name: "Times New Roman" },
    ];

    test("sets body-font-X classNames on each field choice", async function (assert) {
      await renderSetting({
        category: "",
        choices: fonts,
        default: "",
        description: "Base font",
        placeholder: null,
        preview: null,
        secret: false,
        setting: "base_font",
        type: "font_list",
        value: "arial",
      });
      const fontSelector = selectKit(".form-kit__field .font-selector");
      await fontSelector.expand();

      fonts.forEach((choice) => {
        const fontClass = `body-font-${choice.value.replace(/_/g, "-")}`;
        assert.true(
          fontSelector.rowByValue(choice.value).hasClass(fontClass),
          `has ${fontClass} CSS class`
        );
      });
    });
  }
);

module(
  "Integration | Component | SiteSetting | depends_behavior: hidden",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      this.store = this.container.lookup("service:admin-site-setting-store");
      this.parent = SiteSetting.create({
        setting: "parent_flag",
        value: "false",
        default: "false",
        type: "bool",
      });
      this.child = SiteSetting.create({
        setting: "child_value",
        value: "5",
        default: "5",
        type: "integer",
        depends_on: ["parent_flag"],
        depends_behavior: "hidden",
      });
    });

    test("child renders disabled when parent is falsy", async function (assert) {
      this.store.register([this.parent, this.child]);

      await render(
        <template><SiteSettingComponent @setting={{this.child}} /></template>
      );

      assert
        .dom("[data-setting='child_value']")
        .hasClass("disabled-by-dependency");
      assert.dom("input[type='number']").hasAttribute("disabled");
    });

    test("child renders enabled when parent is truthy", async function (assert) {
      this.parent.value = "true";
      this.store.register([this.parent, this.child]);

      await render(
        <template><SiteSettingComponent @setting={{this.child}} /></template>
      );

      assert
        .dom("[data-setting='child_value']")
        .hasNoClass("disabled-by-dependency");
      assert.dom("input[type='number']").doesNotHaveAttribute("disabled");
    });

    test("toggling parent reactively flips child disabled and latches revealed", async function (assert) {
      this.store.register([this.parent, this.child]);

      await render(
        <template>
          <SiteSettingComponent @setting={{this.parent}} />
          <SiteSettingComponent @setting={{this.child}} />
        </template>
      );

      assert.false(this.store.isRevealed(this.child));
      assert
        .dom("[data-setting='child_value']")
        .hasClass("disabled-by-dependency");

      await click("[data-setting='parent_flag'] input[type=checkbox]");
      assert.true(
        this.store.isRevealed(this.child),
        "revealed latched on toggle-on"
      );
      assert
        .dom("[data-setting='child_value']")
        .hasNoClass("disabled-by-dependency");

      await click("[data-setting='parent_flag'] input[type=checkbox]");
      assert.true(this.store.isRevealed(this.child), "revealed stays latched");
      assert
        .dom("[data-setting='child_value']")
        .hasClass("disabled-by-dependency", "disabled again, not re-hidden");
    });

    test("resetting parent to a truthy default latches revealed", async function (assert) {
      this.parent.default = "true";
      this.store.register([this.parent, this.child]);

      await render(
        <template>
          <SiteSettingComponent @setting={{this.parent}} />
          <SiteSettingComponent @setting={{this.child}} />
        </template>
      );

      await click("[data-setting='parent_flag'] .setting-controls__undo");

      assert.true(this.store.isRevealed(this.child));
      assert
        .dom("[data-setting='child_value']")
        .hasNoClass("disabled-by-dependency");
    });
  }
);
