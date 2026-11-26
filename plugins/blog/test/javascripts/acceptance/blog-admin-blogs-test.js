import { click, currentURL, visit } from "@ember/test-helpers";
import { test } from "qunit";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import formKit from "discourse/tests/helpers/form-kit-helper";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

const PLUGIN = {
  id: "blog",
  name: "blog",
  humanized_name: "Blog",
  authors: "Discourse",
  enabled: true,
  enabled_setting: "blog_enabled",
  has_settings: true,
  admin_route: { use_new_show_route: true, location: "blog" },
};

function blogFixture(overrides = {}) {
  return {
    id: 1,
    name: "Fieldnotes",
    slug: "blog",
    url: null,
    description: "Ideas worth sharing",
    about: "About our community",
    category_id: null,
    path_format: "/{slug}",
    posts_per_page: 10,
    is_default: true,
    published: true,
    base_url: "https://blog.example.com",
    problems: [],
    can_delete: false,
    active_theme: { id: "default", name: "Default", preset: true },
    ...overrides,
  };
}

acceptance("Blog admin with one blog", function (needs) {
  needs.user({ admin: true });
  needs.settings({
    blog_enabled: true,
    blog_custom_domains_enabled: true,
    blog_custom_themes_enabled: true,
  });
  needs.site({
    blogs: [{ id: 1, is_default: true, base_url: "https://blog.example.com" }],
  });

  let blog;

  needs.hooks.beforeEach(() => {
    blog = blogFixture();
    pretender.get("/admin/plugins/blog.json", () => response(PLUGIN));
    pretender.get("/admin/plugins/blog/blogs.json", () =>
      response({ blogs: [blog], can_add_blog: true })
    );
    pretender.get("/admin/plugins/blog/blogs/1.json", () => response(blog));
  });

  test("lists the only blog and edits it on a page of its own", async function (assert) {
    await visit("/admin/plugins/blog/blogs");

    assert.dom(".blog-blogs__row").exists({ count: 1 }, "the blog is listed");
    assert
      .dom(".blog-blogs .d-page-subheader")
      .includesText("Add blog", "a second blog can be added from the list");

    await click('.blog-blogs__row[data-blog-id="1"] .blog-blogs__edit');

    assert.strictEqual(
      currentURL(),
      "/admin/plugins/blog/blogs/1/about",
      "the blog's page opens"
    );
    assert
      .dom(".d-page-header")
      .doesNotExist("an edit page has no page header");
    assert.dom(".back-button").exists("the blogs are one click away");
    assert
      .dom(".blog-edit__title")
      .hasText("Fieldnotes", "the page names the blog being edited");
    assert
      .dom(".blog-edit__publish")
      .doesNotExist("the main blog is always published");
  });

  test("offers to set up a blog that has not been named yet", async function (assert) {
    pretender.get("/admin/plugins/blog/blogs.json", () =>
      response({ blogs: [blog], can_add_blog: true, needs_setup: true })
    );

    await visit("/admin/plugins/blog/blogs");

    assert
      .dom(".blog-blogs .empty-state__title")
      .includesText("let's set up your blog", "the admin is greeted");
    assert.dom(".blog-blogs__table").doesNotExist("in place of the list");
    assert
      .dom(".blog-blogs .d-page-subheader")
      .doesNotExist("and without Add blog");

    await click(".blog-blogs .empty-state__cta .btn-primary");

    assert.strictEqual(
      currentURL(),
      "/admin/plugins/blog/blogs/1/about",
      "the button opens the blog's About tab"
    );
  });

  test("keeps the old identity link working", async function (assert) {
    await visit("/admin/plugins/blog/identity");

    assert.strictEqual(
      currentURL(),
      "/admin/plugins/blog/blogs/1/about",
      "old links open the main blog's About tab"
    );
  });

  test("saves the blog's name and description", async function (assert) {
    let saved;
    pretender.put("/admin/plugins/blog/blogs/1.json", (request) => {
      saved = new URLSearchParams(request.requestBody);
      blog = { ...blog, name: saved.get("blog[name]") };
      return response(blog);
    });

    await visit("/admin/plugins/blog/blogs/1/about");
    await formKit(".blog-about__form").field("name").fillIn("New name");
    await formKit(".blog-about__form").submit();

    assert.strictEqual(
      saved.get("blog[name]"),
      "New name",
      "the name is saved"
    );
    assert.strictEqual(
      this.owner.lookup("service:site").blogs[0].name,
      "New name",
      "the editor sees the new name without a reload"
    );
    assert.false(saved.has("blog[path_format]"), "only About fields are sent");
  });

  test("saves the article address format with the blog's publishing settings", async function (assert) {
    const saved = [];
    pretender.put("/admin/plugins/blog/blogs/1.json", (request) => {
      const pathFormat = new URLSearchParams(request.requestBody).get(
        "blog[path_format]"
      );
      saved.push(pathFormat);
      blog = { ...blog, path_format: pathFormat };
      return response(blog);
    });

    await visit("/admin/plugins/blog/blogs/1/settings");
    const today = moment.utc();
    assert
      .dom(".blog-settings")
      .includesText(
        `/${today.format("YYYY/MM")}/my-article`,
        "the monthly format shows today's example"
      );
    assert
      .dom('.blog-settings [name="slug"]')
      .doesNotExist("the main blog lives at /blog, so it has no slug field");

    await formKit(".blog-settings")
      .field("path_format")
      .select("year_month_slug");
    await formKit(".blog-settings").submit();
    // Saving reloads the page's data, which renders a new form.
    await formKit(".blog-settings").field("path_format").select("custom");
    await formKit(".blog-settings")
      .field("custom_path_format")
      .fillIn("/news/{slug}");
    await formKit(".blog-settings").submit();

    assert.deepEqual(
      saved,
      ["/{year}/{month}/{slug}", "/news/{slug}"],
      "presets and custom formats are saved as templates"
    );
  });

  test("offers a custom domain only where the site allows it", async function (assert) {
    await visit("/admin/plugins/blog/blogs/1/settings");
    assert
      .dom(".blog-settings .form-kit__field[data-name='url']")
      .exists("the field is offered");

    this.siteSettings.blog_custom_domains_enabled = false;
    await visit("/admin/plugins/blog/blogs");
    await visit("/admin/plugins/blog/blogs/1/settings");
    assert
      .dom(".blog-settings .form-kit__field[data-name='url'] input")
      .isDisabled("the field is locked");

    blog = { ...blog, url: "https://blog.example.com" };
    await visit("/admin/plugins/blog/blogs");
    await visit("/admin/plugins/blog/blogs/1/settings");
    assert
      .dom(".blog-settings .form-kit__field[data-name='url'] input")
      .isEnabled("a blog that has a custom domain can still clear it");
  });

  test("rejects a custom address format without a unique placeholder", async function (assert) {
    pretender.put("/admin/plugins/blog/blogs/1.json", () => {
      assert.step("saved");
      return response(blog);
    });

    await visit("/admin/plugins/blog/blogs/1/settings");
    const form = formKit(".blog-settings");
    await form.field("path_format").select("custom");
    await form.field("custom_path_format").fillIn("/{year}/{month}");
    await form.submit();

    assert
      .form(".blog-settings")
      .field("custom_path_format")
      .hasError(
        "Start with / and include {slug} or {id}. Only {year}, {month}, {day}, {slug} and {id} can be used."
      );
    assert.verifySteps([], "nothing is saved");
  });

  test("activates a theme for this blog", async function (assert) {
    let activation;
    let listedFor;
    pretender.get("/admin/plugins/blog/themes.json", (request) => {
      listedFor = request.queryParams.blog_id;
      return response({
        themes: [
          {
            id: "default",
            name: "Default",
            preset: true,
            revision: 1,
            accent_color: "d64b2a",
            paper_color: "f5f0e6",
            ink_color: "19382d",
          },
          {
            id: "candidate",
            name: "Candidate",
            revision: 2,
            accent_color: "112233",
            paper_color: "fafafa",
            ink_color: "222222",
          },
        ],
        active: { id: "default" },
        blogs: [{ id: 1, name: "Fieldnotes", active_theme_id: "default" }],
      });
    });
    pretender.post(
      "/admin/plugins/blog/themes/candidate/activate.json",
      (request) => {
        activation = new URLSearchParams(request.requestBody);
        return response({ id: "candidate" });
      }
    );

    await visit("/admin/plugins/blog/blogs/1/theme");
    assert
      .dom(".blog-edit__links a")
      .hasAttribute(
        "href",
        "/admin/plugins/blog/themes",
        "themes are added and edited in the library"
      );
    assert
      .dom('[data-theme-id="candidate"] .blog-theme-card__button.edit')
      .doesNotExist("a blog only picks a theme");
    assert
      .dom('[data-theme-id="candidate"] .blog-theme-card__button.preview')
      .exists("another theme can be previewed on this blog");
    assert
      .dom('[data-theme-id="default"]')
      .exists("the blog's active theme is listed");
    assert
      .dom('[data-theme-id="default"] .blog-theme-card__button.preview')
      .doesNotExist("the blog already shows its active theme");
    assert
      .dom(".blog-edit__nav .active")
      .hasText("Theme", "the tab names the one theme this blog uses");
    await click(
      '[data-theme-id="candidate"] .blog-theme-card__button.activate'
    );
    await click(".dialog-footer .btn-primary");

    assert.strictEqual(listedFor, "1", "previews are built for this blog");
    assert.strictEqual(
      activation.get("blog_id"),
      "1",
      "the theme is activated for this blog"
    );
  });
});

acceptance("Blog admin with several blogs", function (needs) {
  needs.user({ admin: true });
  needs.settings({
    blog_enabled: true,
    blog_custom_domains_enabled: true,
    blog_custom_themes_enabled: true,
  });
  needs.site({
    blogs: [
      { id: 1, is_default: true },
      { id: 2, is_default: false },
    ],
  });

  let engineering;
  let created;

  needs.hooks.beforeEach(() => {
    created = null;
    engineering = blogFixture({
      id: 2,
      name: "Engineering",
      slug: "engineering",
      is_default: false,
      published: false,
      base_url: "https://blog.example.com/blog/engineering",
      can_delete: true,
    });
    pretender.get("/admin/plugins/blog.json", () => response(PLUGIN));
    pretender.get("/admin/plugins/blog/blogs.json", () =>
      response({ blogs: [blogFixture(), engineering], can_add_blog: false })
    );
    pretender.get("/admin/plugins/blog/blogs/2.json", () =>
      response(engineering)
    );
    pretender.post("/admin/plugins/blog/blogs.json", (request) => {
      created = new URLSearchParams(request.requestBody);
      return response(201, engineering);
    });
  });

  test("lists the blogs and leaves out Add blog at the site's limit", async function (assert) {
    await visit("/admin/plugins/blog/blogs");

    assert.dom(".blog-blogs__row").exists({ count: 2 }, "every blog is listed");
    assert
      .dom('.blog-blogs__row[data-blog-id="2"] .blog-blogs__status')
      .includesText("Not published", "a new blog starts unpublished");
    assert
      .dom(".blog-blogs .d-page-subheader")
      .doesNotIncludeText("Add blog", "the site's limit hides Add blog");
  });

  test("adds a blog and opens its page", async function (assert) {
    this.owner
      .lookup("service:site")
      .set("blogs", [{ id: 1, is_default: true }]);

    await visit("/admin/plugins/blog/blogs/new");
    const form = formKit(".blog-new-form");
    await form.field("name").fillIn("Engineering");
    await form.field("slug").fillIn("engineering");
    await form.submit();

    assert.strictEqual(
      created.get("blog[slug]"),
      "engineering",
      "the blog is created"
    );
    assert.strictEqual(
      currentURL(),
      "/admin/plugins/blog/blogs/2/about",
      "its page opens"
    );
    assert.true(
      this.owner
        .lookup("service:site")
        .blogs.some((candidate) => candidate.id === 2),
      "the editor sees the new blog without a reload"
    );
  });

  test("shows a refused slug on its field", async function (assert) {
    pretender.post("/admin/plugins/blog/blogs.json", () =>
      response(422, {
        errors: ["Slug is taken"],
        extras: { field_errors: { slug: ["That slug is taken."] } },
      })
    );

    await visit("/admin/plugins/blog/blogs/new");
    const form = formKit(".blog-new-form");
    await form.field("name").fillIn("Engineering");
    await form.field("slug").fillIn("engineering");
    await form.submit();

    assert
      .dom(
        ".blog-new-form .form-kit__field[data-name='slug'] .form-kit__errors"
      )
      .includesText("That slug is taken.", "the error sits on the slug field");
    assert.dom(".dialog-body").doesNotExist("no popup is shown");
  });

  test("suggests a slug from the name until one is typed", async function (assert) {
    await visit("/admin/plugins/blog/blogs/new");
    const form = formKit(".blog-new-form");
    await form.field("name").fillIn("Product News");

    assert
      .dom(".blog-new-form .form-kit__field[data-name='slug'] input")
      .hasValue("product-news", "the slug follows the name");

    await form.field("slug").fillIn("news");
    await form.field("name").fillIn("Product updates");

    assert
      .dom(".blog-new-form .form-kit__field[data-name='slug'] input")
      .hasValue("news", "a typed slug is kept");
  });

  test("publishes a blog after confirmation", async function (assert) {
    let saved;
    pretender.put("/admin/plugins/blog/blogs/2.json", (request) => {
      saved = new URLSearchParams(request.requestBody);
      return response({ ...engineering, published: true });
    });

    await visit("/admin/plugins/blog/blogs/2/about");
    await click(".blog-edit__publish");
    await click(".dialog-footer .btn-primary");

    assert.strictEqual(
      saved.get("blog[published]"),
      "true",
      "the blog is published"
    );
  });

  test("names the blogs each theme is active on", async function (assert) {
    pretender.get("/admin/plugins/blog/themes.json", () =>
      response({
        themes: [
          {
            id: "candidate",
            name: "Candidate",
            revision: 2,
            accent_color: "112233",
            paper_color: "fafafa",
            ink_color: "222222",
          },
        ],
        active: { id: "default" },
        blogs: [
          { id: 1, name: "Fieldnotes", active_theme_id: "candidate" },
          { id: 2, name: "Engineering", active_theme_id: "candidate" },
        ],
      })
    );

    await visit("/admin/plugins/blog/themes");
    assert
      .dom('[data-theme-id="candidate"] .theme-card__badge.--active')
      .includesText(
        "Active on Fieldnotes, Engineering",
        "both blogs are named"
      );

    await click('[data-theme-id="candidate"] .theme-card__footer-menu');
    assert
      .dom(".blog-theme-card__button.activate")
      .doesNotExist("each blog picks its theme on its own page");
  });

  test("locks the slug and discussion category of a blog with published articles", async function (assert) {
    engineering = { ...engineering, slug_locked: true, category_locked: true };

    await visit("/admin/plugins/blog/blogs/2/settings");

    assert
      .dom('.blog-settings [name="slug"]')
      .isDisabled("the slug keeps published addresses working");
    assert
      .dom(".blog-settings__category")
      .hasClass("is-disabled", "the category keeps published articles public");
    assert
      .dom(".blog-settings .form-kit__field[data-name='category_id']")
      .includesText("cannot be changed", "with the reason beneath it");
  });

  test("greys out Delete while a blog has articles", async function (assert) {
    engineering = { ...engineering, can_delete: false };

    await visit("/admin/plugins/blog/blogs/2/about");

    assert
      .dom(".blog-edit__delete")
      .isDisabled("deleting would orphan its articles");
  });
});

acceptance(
  "Blog admin list after a blog is added or deleted",
  function (needs) {
    needs.user({ admin: true });
    needs.settings({
      blog_enabled: true,
      blog_custom_domains_enabled: true,
      blog_custom_themes_enabled: true,
    });
    needs.site({ blogs: [{ id: 1, is_default: true }] });

    let blogs;

    needs.hooks.beforeEach(() => {
      const engineering = blogFixture({
        id: 2,
        name: "Engineering",
        slug: "engineering",
        is_default: false,
        published: false,
        can_delete: true,
      });
      blogs = [blogFixture()];
      pretender.get("/admin/plugins/blog.json", () => response(PLUGIN));
      pretender.get("/admin/plugins/blog/blogs.json", () =>
        response({ blogs, can_add_blog: true })
      );
      pretender.get("/admin/plugins/blog/blogs/2.json", () =>
        response(engineering)
      );
      pretender.post("/admin/plugins/blog/blogs.json", () => {
        blogs = [...blogs, engineering];
        return response(201, engineering);
      });
      pretender.delete("/admin/plugins/blog/blogs/2.json", () => {
        blogs = blogs.filter((blog) => blog.id !== 2);
        return response(204);
      });
    });

    test("lists a new blog, then drops it once deleted", async function (assert) {
      await visit("/admin/plugins/blog/blogs");
      await click(".blog-blogs .d-page-subheader .btn-primary");
      const form = formKit(".blog-new-form");
      await form.field("name").fillIn("Engineering");
      await form.submit();
      await click(".back-button");

      assert
        .dom(".blog-blogs__row")
        .exists({ count: 2 }, "the new blog is listed without a reload");

      await click('.blog-blogs__row[data-blog-id="2"] .blog-blogs__edit');
      await click(".blog-edit__delete");
      await click(".dialog-footer .btn-danger");

      assert
        .dom(".blog-blogs__row")
        .exists({ count: 1 }, "the deleted blog is gone without a reload");
      assert.deepEqual(
        this.owner.lookup("service:site").blogs.map((blog) => blog.id),
        [1],
        "and from the blogs the editor offers"
      );
    });
  }
);
