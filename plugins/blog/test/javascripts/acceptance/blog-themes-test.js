import {
  click,
  currentURL,
  fillIn as fillControl,
  find,
  triggerEvent,
  visit,
} from "@ember/test-helpers";
import { test } from "qunit";
import sinon from "sinon";
import interceptClick from "discourse/lib/intercept-click";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import formKit from "discourse/tests/helpers/form-kit-helper";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Blog themes and identity", function (needs) {
  needs.user({ admin: true });
  needs.settings({ blog_enabled: true });
  needs.site({ blog_base_url: "https://blog.example.com" });

  let active;
  let draft;
  needs.hooks.beforeEach(() => {
    pretender.get("/admin/plugins/blog.json", () =>
      response({
        id: "blog",
        name: "blog",
        humanized_name: "Blog",
        authors: "Discourse",
        enabled: true,
        enabled_setting: "blog_enabled",
        has_settings: true,
        admin_route: { use_new_show_route: true, location: "blog" },
      })
    );
    pretender.get("/blog-editor/theme-authoring.json", () =>
      response({
        templates: Object.fromEntries(
          ["layout", "index", "article", "about", "not_found"].map((name) => [
            `template_${name}`,
            "<h1>{{ site.title }}</h1>",
          ])
        ),
        articles: [{ id: 1, title: "Published sample" }],
        variables: {
          site: { title: "Example blog" },
          article: {
            title: "Published sample",
            body_html: "<p>Sample body</p>",
          },
        },
      })
    );
    active = {
      id: "live",
      name: "Current appearance",
      revision: 2,
      preview_url: "https://blog.example.com/?blog_theme_preview=live",
      accent_color: "d64b2a",
      paper_color: "f5f0e6",
      ink_color: "19382d",
      css: "",
      javascript: "",
    };
    draft = {
      ...active,
      id: "candidate",
      name: "Candidate",
      revision: 1,
      preview_url: "https://blog.example.com/?blog_theme_preview=signed",
    };
    pretender.get("/blog-editor/themes.json", () =>
      response({ themes: [draft], active })
    );
    pretender.get("/blog-editor/themes/candidate.json", () =>
      response({ theme: draft, active })
    );
    const settings = {
      blog_title: "Fieldnotes",
      blog_description: "Ideas worth sharing",
      blog_about: "About our community",
    };
    pretender.get("/admin/site_settings.json", () =>
      response({
        site_settings: Object.entries(settings).map(([setting, value]) => ({
          setting,
          value,
        })),
      })
    );
  });

  test("separates the themes list from focused theme editing and identity", async function (assert) {
    await visit("/admin/plugins/blog/themes");
    assert
      .dom(".admin-plugin-config-page__top-nav-item")
      .exists(
        { count: 3 },
        "Settings, Themes, and Identity are distinct sections"
      );
    assert
      .dom(".blog-theme-editor__form")
      .doesNotExist("the list does not contain code editors");
    assert
      .dom(".blog-identity__form")
      .doesNotExist("identity is not mixed into the themes list");
    await click('[data-theme-id="candidate"] a');
    assert.strictEqual(
      currentURL(),
      "/admin/plugins/blog/themes/candidate/edit",
      "a theme opens its own URL"
    );
    assert
      .dom(".blog-themes")
      .doesNotExist("the list is absent from the focused editor");
    assert
      .dom(".blog-theme-editor__form")
      .exists("only the selected theme form is shown");
    assert
      .dom(".blog-theme-editor__javascript")
      .doesNotHaveAttribute("open", "JavaScript starts collapsed");
    for (const name of ["accent_color", "paper_color", "ink_color"]) {
      assert.true(
        Boolean(find(`[data-name="${name}"]`).closest(".form-kit__col")),
        `${name} retains its label containment`
      );
    }
  });

  test("saves a draft without activation and blocks activating unsaved edits", async function (assert) {
    pretender.put("/blog-editor/themes/candidate.json", (request) => {
      const values = new URLSearchParams(request.requestBody);
      assert.strictEqual(
        values.get("theme[css]"),
        ".blog { font-size: 18px; }",
        "CSS reaches the draft endpoint"
      );
      assert.strictEqual(
        values.get("theme[javascript]"),
        "window.demo = true;",
        "JavaScript reaches the draft endpoint"
      );
      draft = { ...draft, revision: 2 };
      return response(draft);
    });
    await visit("/admin/plugins/blog/themes/candidate/edit");
    const form = formKit(".blog-theme-editor__form");
    await form.field("css").fillIn(".blog { font-size: 18px; }");
    await click(".blog-theme-editor__javascript summary");
    await form.field("javascript").fillIn("window.demo = true;");
    await form.submit();
    assert
      .dom(".blog-theme-editor__preview-draft")
      .isNotDisabled("a saved draft can be previewed");
    await formKit(".blog-theme-editor__form").field("name").fillIn("Unsaved");
    assert
      .dom(".blog-theme-editor__activate")
      .isDisabled("unsaved edits cannot be activated");
    assert
      .dom(".blog-theme-editor")
      .includesText(
        "Save your changes before activating this draft",
        "unsaved edits are called out before activating"
      );
  });

  test("edits Liquid templates as a saved draft without activating them", async function (assert) {
    pretender.put("/blog-editor/themes/candidate.json", (request) => {
      const values = new URLSearchParams(request.requestBody);
      assert.strictEqual(
        values.get("theme[template_index]"),
        "<h1>{{ site.title }}</h1>",
        "Liquid is sent unchanged to the draft endpoint"
      );
      draft = {
        ...draft,
        revision: 2,
        template_index: values.get("theme[template_index]"),
      };
      return response(draft);
    });
    await visit("/admin/plugins/blog/themes/candidate/edit");
    assert
      .dom('[data-authoring-tab="design"]')
      .hasAttribute(
        "aria-current",
        "true",
        "the design fields are the default tab"
      );
    await click('[data-authoring-tab="template_index"]');
    assert
      .dom('[data-authoring-tab="template_index"]')
      .hasAttribute("aria-current", "true", "each template is its own tab");
    assert
      .dom('[data-authoring-tab="design"]')
      .doesNotHaveAttribute("aria-current");
    await click(".blog-theme-editor__customize");
    const form = formKit(".blog-theme-editor__form");
    assert
      .dom('[data-name="template_index"]')
      .hasClass(
        "blog-theme-editor__template-field",
        "the custom editor receives its full-width layout"
      );
    await fillControl(
      '[data-name="template_index"] textarea',
      "<h1>{{ site.title }}</h1>"
    );
    assert
      .dom(".blog-theme-editor__activate")
      .isDisabled("unsaved template edits cannot be activated");
    await form.submit();
    assert
      .dom(".blog-theme-editor__preview-draft")
      .isNotDisabled("the saved template can be previewed before activation");
  });

  test("customizes one effective template, inserts a variable, and restores its default", async function (assert) {
    await visit("/admin/plugins/blog/themes/candidate/edit");
    await click('[data-authoring-tab="template_layout"]');
    assert
      .dom(".blog-theme-editor__builtin code")
      .includesText(
        "site.title",
        "the effective default is visible before editing"
      );
    await click(".blog-theme-editor__customize");
    assert
      .dom('[data-name="template_layout"] .ace_content')
      .includesText(
        "site.title",
        "customizing starts with visible working source"
      );
    assert
      .dom('[data-name="template_index"]')
      .doesNotExist("other templates are not stacked below it");

    await fillControl(
      '[data-name="template_layout"] textarea',
      "<main>Unsaved author edits</main>"
    );
    const editor = find(".blog-theme-editor__template-control");

    await click(".blog-theme-editor__variables");
    assert
      .dom(".blog-theme-variables")
      .exists("the variable reference opens in a modal");
    await fillControl(
      'input[aria-label="Find a variable"]',
      "article.body_html"
    );
    assert
      .dom(".blog-theme-variables__item")
      .exists({ count: 1 }, "the reference can be filtered");
    assert
      .dom(".blog-theme-variables__item")
      .includesText("Trusted HTML", "trusted fragments are identified");
    await click(".blog-theme-variables__insert");
    assert
      .dom(".blog-theme-variables")
      .doesNotExist("inserting a snippet closes the reference");
    assert
      .dom('[data-name="template_layout"] .ace_content')
      .includesText(
        "article.body_html",
        "the inserted snippet is visible in the editor"
      );
    assert
      .dom('[data-name="template_layout"] .ace_content')
      .includesText(
        "Unsaved author edits",
        "inserting preserves the author's changes"
      );
    assert.strictEqual(
      find(".blog-theme-editor__template-control"),
      editor,
      "programmatic changes update the existing editor without remounting"
    );

    await click('[data-authoring-tab="design"]');
    await click('[data-authoring-tab="template_layout"]');
    assert
      .dom('[data-name="template_layout"] .ace_content')
      .includesText(
        "article.body_html",
        "FormKit retains the snippet across tab changes"
      );

    await click(".blog-theme-editor__restore-default");
    await click(".dialog-footer .btn-primary");
    assert
      .dom(".blog-theme-editor__builtin code")
      .exists("restoring returns to the visible built-in template");
    assert
      .dom('[data-name="template_layout"]')
      .doesNotExist(
        "the override is removed rather than replaced with a hidden copy"
      );
  });

  test("previews unsaved changes in a modal without saving or activating", async function (assert) {
    const previewedPages = [];
    pretender.post("/blog-editor/theme-authoring/preview.json", (request) => {
      const values = new URLSearchParams(request.requestBody);
      previewedPages.push(values.get("page"));
      assert.strictEqual(
        values.get("theme[css]"),
        ".blog { color: blue; }",
        "design edits survive unmounting their tab"
      );
      assert.strictEqual(
        values.get("theme[template_index]"),
        "<h1>Unsaved preview</h1>",
        "preview includes unsaved template changes"
      );
      assert.strictEqual(
        values.get("article_id"),
        "1",
        "the selected public article is used"
      );
      return response({ url: `about:blank#preview-${previewedPages.length}` });
    });
    await visit("/admin/plugins/blog/themes/candidate/edit");
    await formKit(".blog-theme-editor__form")
      .field("css")
      .fillIn(".blog { color: blue; }");
    await click('[data-authoring-tab="template_index"]');
    await click(".blog-theme-editor__customize");
    await fillControl(
      '[data-name="template_index"] textarea',
      "<h1>Unsaved preview</h1>"
    );
    await click(".blog-theme-editor__preview-draft");
    assert
      .dom(".blog-theme-preview__frame")
      .hasAttribute(
        "src",
        "about:blank#preview-1",
        "the working snapshot is displayed"
      );
    assert
      .dom(".blog-theme-editor__activate")
      .isDisabled("previewing does not commit unsaved changes");

    await fillControl('select[aria-label="Page to preview"]', "article");
    assert
      .dom(".blog-theme-preview__frame")
      .hasAttribute(
        "src",
        "about:blank#preview-2",
        "picking another page re-previews it without a refresh button"
      );
    await fillControl('select[aria-label="Preview size"]', "mobile");
    assert
      .dom(".blog-theme-preview__frame")
      .hasAttribute(
        "data-size",
        "mobile",
        "mobile preview has its own viewport"
      );

    assert.deepEqual(
      previewedPages,
      ["index", "article"],
      "the preview follows the edited template, then the page picked in the modal"
    );

    await click(".d-modal__footer .btn");
    assert
      .dom(".blog-theme-preview")
      .doesNotExist("closing returns to the editor");
    assert
      .dom('[data-name="template_index"] .ace_content')
      .includesText("Unsaved preview", "template edits survive previewing");
  });

  test("explains that article previews need a published article", async function (assert) {
    let previews = 0;
    pretender.get("/blog-editor/theme-authoring.json", () =>
      response({
        templates: { template_article: "<h1>{{ site.title }}</h1>" },
        articles: [],
        variables: { site: { title: "Example blog" } },
      })
    );
    pretender.post("/blog-editor/theme-authoring/preview.json", () => {
      previews++;
      return response({ url: "about:blank#preview" });
    });

    await visit("/admin/plugins/blog/themes/candidate/edit");
    await click('[data-authoring-tab="template_article"]');
    await click(".blog-theme-editor__preview-draft");
    assert
      .dom(".blog-theme-preview__frame")
      .exists("without a published article the homepage stands in");

    await fillControl('select[aria-label="Page to preview"]', "article");
    assert
      .dom(".blog-theme-preview__empty")
      .includesText(
        "Article previews need a published article",
        "the article page explains what it needs"
      );
    assert.strictEqual(previews, 1, "no preview is requested for that page");
  });

  test("marks customized templates on their tab and names the state above the editor", async function (assert) {
    await visit("/admin/plugins/blog/themes/candidate/edit");
    assert
      .dom(".blog-theme-editor__tabs .nav-pills > li")
      .exists({ count: 6 }, "design and every template have a tab");
    assert
      .dom(".blog-theme-editor__state")
      .doesNotExist("the design tab needs no template state");

    await click('[data-authoring-tab="template_about"]');
    assert
      .dom(".blog-theme-editor__state")
      .includesText(
        "Built-in template",
        "an untouched template is named as built-in"
      );
    assert
      .dom('[data-authoring-tab="template_about"] .blog-theme-editor__marker')
      .doesNotExist("built-in tabs carry no marker");

    await click(".blog-theme-editor__customize");
    assert
      .dom(".blog-theme-editor__state")
      .includesText("Custom template", "the state follows the override");
    assert
      .dom('[data-authoring-tab="template_about"] .blog-theme-editor__marker')
      .exists("a customized template is marked on its tab");
    assert
      .dom('[data-authoring-tab="design"] .blog-theme-editor__marker')
      .doesNotExist("the design tab is never marked");

    await click('[data-authoring-tab="template_layout"]');
    assert
      .dom(".blog-theme-editor__state")
      .includesText("Built-in template", "switching tabs switches the state");
    assert
      .dom('[data-authoring-tab="template_about"] .blog-theme-editor__marker')
      .exists("the marker stays on the customized tab");
  });

  test("activates a saved draft only after confirmation", async function (assert) {
    pretender.post("/blog-editor/themes/candidate/activate.json", (request) => {
      assert.strictEqual(
        new URLSearchParams(request.requestBody).get("revision"),
        "1",
        "the reviewed revision is activated"
      );
      assert.step("activated");
      return response(draft);
    });
    await visit("/admin/plugins/blog/themes/candidate/edit");
    await click(".blog-theme-editor__activate");
    assert.verifySteps([], "opening confirmation makes no changes");
    await click(".dialog-footer .btn-primary");
    assert.verifySteps(["activated"], "confirmation activates the draft");
  });

  test("creates a theme on its own page then opens the persisted editor", async function (assert) {
    pretender.post("/blog-editor/themes.json", () => response(draft));
    await visit("/admin/plugins/blog/themes/new");
    assert
      .dom(".blog-themes")
      .doesNotExist("new theme creation has no list alongside it");
    await formKit(".blog-theme-editor__form").field("name").fillIn("Candidate");
    await formKit(".blog-theme-editor__form").submit();
    assert.strictEqual(
      currentURL(),
      "/admin/plugins/blog/themes/candidate/edit",
      "save opens the persisted theme without a dirty-form prompt"
    );
  });

  test("offers Import and exports only saved themes", async function (assert) {
    await visit("/admin/plugins/blog/themes");
    assert
      .dom(".d-page-subheader .btn-default")
      .hasText("Import", "the list offers a general import action");

    await visit("/admin/plugins/blog/themes/candidate/edit");
    assert
      .dom(".blog-theme-editor__export")
      .hasAttribute(
        "href",
        "/blog-editor/themes/candidate/export",
        "exports the saved draft"
      )
      .hasAttribute("download", "", "downloads rather than navigating");

    const event = {
      target: find(".blog-theme-editor__export"),
      preventDefault: sinon.spy(),
    };
    interceptClick(event);
    assert.false(
      event.preventDefault.called,
      "the client router leaves the download to the browser"
    );

    await visit("/admin/plugins/blog/themes/new");
    assert
      .dom(".blog-theme-editor__export")
      .doesNotExist("a theme must be saved before it can be exported");
  });

  test("imports a ZIP file and opens the imported draft", async function (assert) {
    const file = new File(["theme archive"], "theme.zip", {
      type: "application/zip",
    });
    pretender.post("/blog-editor/themes/import.json", (request) => {
      assert.strictEqual(
        request.requestBody.get("file"),
        file,
        "the archive is sent as multipart form data"
      );
      assert.false(
        request.requestBody.has("repository"),
        "no Git source is sent"
      );
      return response(draft);
    });

    await visit("/admin/plugins/blog/themes/import/new");
    await click('input[type="radio"][value="file"]');
    assert.dom('[name="repository"]').doesNotExist("Git fields are hidden");
    assert
      .dom(".blog-theme-import .pick-files-button button")
      .isVisible("a visible button opens the file picker")
      .hasText("Choose ZIP file", "the picker describes the supported format");

    const fileInput = find('.blog-theme-import input[type="file"]');
    const openPicker = sinon.stub(fileInput, "click");
    try {
      await click(".blog-theme-import .pick-files-button button");
      assert.true(
        openPicker.calledOnce,
        "the button opens the system file picker"
      );
    } finally {
      openPicker.restore();
    }

    await triggerEvent('.blog-theme-import input[type="file"]', "change", {
      files: [file],
    });
    assert
      .dom(".blog-theme-import__filename")
      .hasText(
        "theme.zip",
        "the selected filename is visible before importing"
      );
    await formKit(".blog-theme-import__form").submit();

    assert.strictEqual(
      currentURL(),
      "/admin/plugins/blog/themes/candidate/edit",
      "import opens the new draft"
    );
  });

  test("imports Git on a separate page and opens the imported draft", async function (assert) {
    pretender.post("/blog-editor/themes/import.json", (request) => {
      const values = new URLSearchParams(request.requestBody);
      assert.strictEqual(
        values.get("repository"),
        "https://github.com/example/theme",
        "the source URL is submitted"
      );
      draft = {
        ...draft,
        source: {
          repository: values.get("repository"),
          branch: "design",
          commit: "abc123",
        },
      };
      return response(draft);
    });
    await visit("/admin/plugins/blog/themes/import/new");
    assert
      .dom(".blog-theme-editor__form")
      .doesNotExist("import is not mixed with theme editing");
    const form = formKit(".blog-theme-import__form");
    await form.field("repository").fillIn("https://github.com/example/theme");
    await form.field("branch").fillIn("design");
    await form.submit();
    assert.strictEqual(
      currentURL(),
      "/admin/plugins/blog/themes/candidate/edit",
      "import opens the focused editor"
    );
    assert
      .dom(".blog-theme-editor__source")
      .includesText("abc123", "the source is retained in its own disclosure");
  });

  test("saves identity separately through the audited settings endpoint", async function (assert) {
    pretender.put("/admin/site_settings/bulk_update.json", (request) => {
      const values = new URLSearchParams(request.requestBody);
      assert.strictEqual(
        values.get("settings[blog_title][value]"),
        "New identity",
        "identity is saved"
      );
      assert.false(
        [...values.keys()].some((key) => key.includes("custom_css")),
        "identity never publishes theme code"
      );
      return response(204);
    });
    await visit("/admin/plugins/blog/identity");
    assert.dom(".blog-themes").doesNotExist("identity contains no themes list");
    assert
      .dom(".blog-theme-editor__form")
      .doesNotExist("identity contains no theme editor");
    const form = formKit(".blog-identity__form");
    await form.field("blog_title").fillIn("New identity");
    await form.submit();
  });

  test("warns before leaving a theme with unsaved changes", async function (assert) {
    await visit("/admin/plugins/blog/themes/candidate/edit");
    await formKit(".blog-theme-editor__form")
      .field("name")
      .fillIn("Unsaved name");
    await click('a[href="/admin/plugins/blog/themes"]');
    assert
      .dom(".dialog-body")
      .exists("FormKit asks before discarding theme edits");
    assert
      .dom(".blog-theme-editor__form")
      .exists("the editor remains until navigation is confirmed");
    await click(".dialog-footer .btn-primary");
    assert.strictEqual(
      currentURL(),
      "/admin/plugins/blog/themes",
      "confirmation returns to the list"
    );
  });

  test("theme covers show a shared specimen and the saved palette", async function (assert) {
    await visit("/admin/plugins/blog/themes");

    assert
      .dom(".blog-theme-thumbnail__headline")
      .hasText("Stay curious.", "the cover shows readable sample typography");
    assert
      .dom(".blog-theme-thumbnail__excerpt")
      .hasText(
        "Notes on making things, staying curious, and finding meaning in the everyday.",
        "the cover includes a sample excerpt"
      );
    assert
      .dom(".blog-theme-thumbnail__caption")
      .hasText("Theme palette", "the cover identifies its palette specimen");
    const style = find(".blog-theme-thumbnail").style;
    assert.strictEqual(
      style.getPropertyValue("--blog-theme-paper").trim(),
      "#f5f0e6",
      "the cover uses the saved paper color"
    );
    assert.strictEqual(
      style.getPropertyValue("--blog-theme-ink").trim(),
      "#19382d",
      "the cover uses the saved ink color"
    );
    assert.strictEqual(
      style.getPropertyValue("--blog-theme-accent").trim(),
      "#d64b2a",
      "the cover uses the saved accent color"
    );
    assert
      .dom(".blog-theme-thumbnail__swatch")
      .exists({ count: 3 }, "all three palette colors have swatches");
  });

  test("theme covers fall back safely for missing or invalid colors", async function (assert) {
    draft.paper_color = null;
    draft.ink_color = "invalid";
    draft.accent_color = "abcdef; background: url(https://example.com/image)";

    await visit("/admin/plugins/blog/themes");

    const style = find(".blog-theme-thumbnail").style;
    for (const [name, fallback] of [
      ["paper", "secondary"],
      ["ink", "primary"],
      ["accent", "tertiary"],
    ]) {
      assert.strictEqual(
        style.getPropertyValue(`--blog-theme-${name}`).trim(),
        `var(--${fallback})`,
        `invalid ${name} falls back to the admin palette`
      );
    }
    assert.strictEqual(
      style.length,
      3,
      "invalid colors cannot inject declarations"
    );
  });

  test("lists each design as a card with its palette, state, and actions", async function (assert) {
    const imported = {
      ...draft,
      source: {
        repository: "https://example.com/blog-theme.git",
        branch: "main",
        commit: "abc1234",
      },
      locally_modified: true,
    };
    pretender.get("/blog-editor/themes.json", () =>
      response({ themes: [active, imported], active })
    );

    await visit("/admin/plugins/blog/themes");
    assert.dom(".theme-card").exists({ count: 2 }, "each design is a card");
    assert
      .dom(`.theme-card[data-theme-id="live"] .blog-theme-thumbnail`)
      .exists("cards show a preview built from the theme palette");
    assert
      .dom(`.theme-card[data-theme-id="live"] .theme-card__badge`)
      .includesText("Active", "the live design is badged");
    assert
      .dom(`.theme-card[data-theme-id="candidate"] .theme-card__badge`)
      .includesText("Local edits", "local Git edits are badged");
    assert
      .dom(`.theme-card[data-theme-id="live"] .theme-card__description`)
      .includesText("Draft revision 2", "the card names the saved revision");
    await click(
      `.theme-card[data-theme-id="candidate"] .theme-card__footer-menu`
    );
    assert
      .dom(
        '[data-identifier="blog-theme-actions-candidate"] .theme-card__button'
      )
      .exists(
        { count: 4 },
        "a Git design offers activate, pull, preview, and delete"
      );
    assert
      .dom(
        '[data-identifier="blog-theme-actions-candidate"] .d-icon-cloud-arrow-down'
      )
      .exists("its Git source can be pulled");
    assert
      .dom('[data-identifier="blog-theme-actions-candidate"] .preview')
      .hasAttribute(
        "href",
        draft.preview_url,
        "the saved revision can be previewed without activating it"
      );

    await click(`.theme-card[data-theme-id="live"] .theme-card__footer-menu`);
    assert
      .dom('[data-identifier="blog-theme-actions-live"] .theme-card__button')
      .exists({ count: 3 }, "a design without a Git source cannot be pulled");
    assert
      .dom('[data-identifier="blog-theme-actions-live"] .preview')
      .exists("the live design keeps a useful action");
    assert
      .dom(
        '[data-identifier="blog-theme-actions-live"] .d-icon-cloud-arrow-down'
      )
      .doesNotExist("its menu has no pull item");
    assert
      .dom('[data-identifier="blog-theme-actions-live"] .d-icon-play')
      .exists("activation stays available");
    assert
      .dom(`.theme-card[data-theme-id="live"] .theme-card__footer-menu`)
      .exists("the menu belongs to the card it was opened from");
  });

  test("activating from a card confirms first and reloads the list", async function (assert) {
    let listLoads = 0;
    pretender.get("/blog-editor/themes.json", () => {
      listLoads++;
      return response({ themes: [active, draft], active });
    });
    pretender.post("/blog-editor/themes/candidate/activate.json", () => {
      assert.step("activated");
      return response(draft);
    });

    await visit("/admin/plugins/blog/themes");
    await click(
      `.theme-card[data-theme-id="candidate"] .theme-card__footer-menu`
    );
    const loadsBeforeActivating = listLoads;
    await click(
      '[data-identifier="blog-theme-actions-candidate"] .theme-card__button:not([disabled])'
    );
    assert.verifySteps([], "opening the confirmation changes nothing");
    await click(".dialog-footer .btn-primary");
    assert.verifySteps(["activated"], "confirming activates the design");
    assert.true(
      listLoads > loadsBeforeActivating,
      "the list reloads after activating"
    );
  });

  test("pulling from a card refreshes the design and its badges", async function (assert) {
    let theme = {
      ...draft,
      source: {
        repository: "https://example.com/blog-theme.git",
        branch: "main",
        commit: "abc1234",
      },
      locally_modified: true,
    };
    pretender.get("/blog-editor/themes.json", () =>
      response({ themes: [active, theme], active })
    );
    pretender.post("/blog-editor/themes/candidate/pull.json", (request) => {
      assert.strictEqual(
        new URLSearchParams(request.requestBody).get("revision"),
        "1",
        "the saved revision is pulled"
      );
      assert.step("pulled");
      theme = { ...theme, locally_modified: false, revision: 2 };
      return response(theme);
    });

    await visit("/admin/plugins/blog/themes");
    assert
      .dom(`.theme-card[data-theme-id="candidate"] .theme-card__badge`)
      .includesText("Local edits", "local edits are flagged before pulling");

    await click(
      `.theme-card[data-theme-id="candidate"] .theme-card__footer-menu`
    );
    await click(
      '[data-identifier="blog-theme-actions-candidate"] .d-icon-cloud-arrow-down'
    );
    await click(".dialog-footer .btn-primary");
    assert.verifySteps(["pulled"], "confirming pulls the latest commit");
    assert
      .dom(`.theme-card[data-theme-id="candidate"] .theme-card__badge`)
      .doesNotExist("the badge clears once the list reloads");
  });

  test("preserves the old appearance URL as a redirect to themes", async function (assert) {
    await visit("/admin/plugins/blog/appearance");
    assert.strictEqual(
      currentURL(),
      "/admin/plugins/blog/themes",
      "old bookmarks open the themes index"
    );
  });
});
