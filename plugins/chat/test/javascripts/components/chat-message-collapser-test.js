import componentTest, {
  setupRenderingTest,
} from "discourse/tests/helpers/component-test";
import { click, render } from "@ember/test-helpers";
import hbs from "htmlbars-inline-precompile";
import {
  query,
  queryAll,
  visible,
} from "discourse/tests/helpers/qunit-helpers";
import { module, test } from "qunit";

const youtubeCooked =
  "<p>written text</p>" +
  '<div class="onebox lazyYT-container" data-youtube-id="ytId1" data-youtube-title="Cats are great">Vid 1</div>' +
  "<p>more written text</p>" +
  '<div class="onebox lazyYT-container" data-youtube-id="ytId2" data-youtube-title="Kittens are great">Vid 2</div>' +
  "<p>and even more</p>";

const animatedImageCooked =
  "<p>written text</p>" +
  '<p><img src="/images/avatar.png" class="animated onebox"></img></p>' +
  "<p>more written text</p>" +
  '<p><img src="/images/d-logo-sketch-small.png" class="animated onebox"></img></p>' +
  "<p>and even more</p>";

const externalImageCooked =
  "<p>written text</p>" +
  '<p><a href="http://cat1.com" class="onebox"><img src=""></img></a></p>' +
  "<p>more written text</p>" +
  '<p><a href="http://cat2.com" class="onebox"><img src=""></img></a></p>' +
  "<p>and even more</p>";

const imageCooked =
  "<p>written text</p>" +
  '<p><img src="/images/avatar.png" alt="shows alt"></p>' +
  "<p>more written text</p>" +
  '<p><img src="/images/d-logo-sketch-small.png" alt=""></p>' +
  "<p>and even more</p>" +
  '<p><img src="/images/d-logo-sketch.png" class="emoji"></p>';

const galleryCooked =
  "<p>written text</p>" +
  '<div class="onebox imgur-album">' +
  '<a href="https://imgur.com/gallery/yyVx5lJ">' +
  '<span class="outer-box"><span><span class="album-title">Le tomtom album</span></span></span>' +
  '<img src="/images/avatar.png" title="Solution" height="315" width="600">' +
  "</a>" +
  "</div>" +
  "<p>more written text</p>";

const evilString = "<script>someeviltitle</script>";
const evilStringEscaped = "&lt;script&gt;someeviltitle&lt;/script&gt;";

module("Discourse Chat | Component | chat message collapser", function (hooks) {
  setupRenderingTest(hooks);

  test("escapes uploads header", async function (assert) {
    this.set("uploads", [{ original_filename: evilString }]);
    await render(hbs`{{chat-message-collapser uploads=uploads}}`);

    assert.ok(
      query(".chat-message-collapser-link-small").innerHTML.includes(
        evilStringEscaped
      )
    );
  });
});

module(
  "Discourse Chat | Component | chat message collapser youtube",
  function (hooks) {
    setupRenderingTest(hooks);

    test("escapes youtube header", async function (assert) {
      this.set("cooked", youtubeCooked.replace("ytId1", evilString));
      await render(hbs`{{chat-message-collapser cooked=cooked}}`);

      assert.ok(
        query(".chat-message-collapser-link").href.includes(
          "%3Cscript%3Esomeeviltitle%3C/script%3E"
        )
      );
    });

    componentTest("shows youtube link in header", {
      template: hbs`{{chat-message-collapser cooked=cooked}}`,

      beforeEach() {
        this.set("cooked", youtubeCooked);
      },

      async test(assert) {
        const link = document.querySelectorAll(".chat-message-collapser-link");

        assert.equal(link.length, 2, "two youtube links rendered");
        assert.strictEqual(
          link[0].href,
          "https://www.youtube.com/watch?v=ytId1"
        );
        assert.strictEqual(
          link[1].href,
          "https://www.youtube.com/watch?v=ytId2"
        );
      },
    });

    componentTest("shows all user written text", {
      template: hbs`{{chat-message-collapser cooked=cooked}}`,

      beforeEach() {
        youtubeCooked.youtubeid;
        this.set("cooked", youtubeCooked);
      },

      async test(assert) {
        const text = document.querySelectorAll(".chat-message-collapser p");

        assert.equal(text.length, 3, "shows all written text");
        assert.strictEqual(
          text[0].innerText,
          "written text",
          "first line of written text"
        );
        assert.strictEqual(
          text[1].innerText,
          "more written text",
          "third line of written text"
        );
        assert.strictEqual(
          text[2].innerText,
          "and even more",
          "fifth line of written text"
        );
      },
    });

    componentTest("collapses and expands cooked youtube", {
      template: hbs`{{chat-message-collapser cooked=cooked}}`,

      beforeEach() {
        this.set("cooked", youtubeCooked);
      },

      async test(assert) {
        const youtubeDivs = document.querySelectorAll(".onebox");

        assert.equal(youtubeDivs.length, 2, "two youtube previews rendered");

        await click(
          document.querySelectorAll(".chat-message-collapser-opened")[0],
          "close first preview"
        );

        assert.notOk(
          visible(".onebox[data-youtube-id='ytId1']"),
          "first youtube preview hidden"
        );
        assert.ok(
          visible(".onebox[data-youtube-id='ytId2']"),
          "second youtube preview still visible"
        );

        await click(".chat-message-collapser-closed");

        assert.equal(youtubeDivs.length, 2, "two youtube previews rendered");

        await click(
          document.querySelectorAll(".chat-message-collapser-opened")[1],
          "close second preview"
        );

        assert.ok(
          visible(".onebox[data-youtube-id='ytId1']"),
          "first youtube preview still visible"
        );
        assert.notOk(
          visible(".onebox[data-youtube-id='ytId2']"),
          "second youtube preview hidden"
        );

        await click(".chat-message-collapser-closed");

        assert.equal(youtubeDivs.length, 2, "two youtube previews rendered");
      },
    });
  }
);

module(
  "Discourse Chat | Component | chat message collapser images",
  function (hooks) {
    setupRenderingTest(hooks);
    const imageTextCooked = "<p>A picture of Tomtom</p>";

    componentTest("shows filename for one image", {
      template: hbs`{{chat-message-collapser cooked=cooked uploads=uploads}}`,

      beforeEach() {
        this.set("cooked", imageTextCooked);
        this.set("uploads", [{ original_filename: "tomtom.jpeg" }]);
      },

      async test(assert) {
        assert.ok(
          query(".chat-message-collapser-link-small").innerText.includes(
            "tomtom.jpeg"
          )
        );
      },
    });

    componentTest("shows number of files for multiple images", {
      template: hbs`{{chat-message-collapser cooked=cooked uploads=uploads}}`,

      beforeEach() {
        this.set("cooked", imageTextCooked);
        this.set("uploads", [{}, {}]);
      },

      async test(assert) {
        assert.ok(
          query(".chat-message-collapser-link-small").innerText.includes(
            "2 files"
          )
        );
      },
    });

    componentTest("collapses and expands images", {
      template: hbs`{{chat-message-collapser cooked=cooked uploads=uploads}}`,

      beforeEach() {
        this.set("cooked", imageTextCooked);
        this.set("uploads", [{ original_filename: "tomtom.png" }]);
      },

      async test(assert) {
        const uploads = ".chat-uploads";
        const chatImageUpload = ".chat-img-upload";

        assert.ok(visible(uploads));
        assert.ok(visible(chatImageUpload));

        await click(".chat-message-collapser-opened");

        assert.notOk(visible(uploads));
        assert.notOk(visible(chatImageUpload));

        await click(".chat-message-collapser-closed");

        assert.ok(visible(uploads));
        assert.ok(visible(chatImageUpload));
      },
    });
  }
);

module(
  "Discourse Chat | Component | chat message collapser animated image",
  function (hooks) {
    setupRenderingTest(hooks);

    componentTest("shows links for animated image", {
      template: hbs`{{chat-message-collapser cooked=cooked}}`,

      beforeEach() {
        this.set("cooked", animatedImageCooked);
      },

      async test(assert) {
        const links = document.querySelectorAll(
          "a.chat-message-collapser-link-small"
        );

        assert.ok(links[0].innerText.trim().includes("avatar.png"));
        assert.ok(links[0].href.includes("avatar.png"));

        assert.ok(
          links[1].innerText.trim().includes("d-logo-sketch-small.png")
        );
        assert.ok(links[1].href.includes("d-logo-sketch-small.png"));
      },
    });

    componentTest("shows all user written text", {
      template: hbs`{{chat-message-collapser cooked=cooked}}`,

      beforeEach() {
        this.set("cooked", animatedImageCooked);
      },

      async test(assert) {
        const text = document.querySelectorAll(".chat-message-collapser p");

        assert.equal(text.length, 5, "shows all written text");
        assert.strictEqual(text[0].innerText, "written text");
        assert.strictEqual(text[2].innerText, "more written text");
        assert.strictEqual(text[4].innerText, "and even more");
      },
    });

    componentTest("collapses and expands animated image onebox", {
      template: hbs`{{chat-message-collapser cooked=cooked}}`,

      beforeEach() {
        this.set("cooked", animatedImageCooked);
      },

      async test(assert) {
        const animatedOneboxes = document.querySelectorAll(".animated.onebox");

        assert.equal(animatedOneboxes.length, 2, "two oneboxes rendered");

        await click(
          document.querySelectorAll(".chat-message-collapser-opened")[0],
          "close first preview"
        );

        assert.notOk(
          visible(".onebox[src='/images/avatar.png']"),
          "first onebox hidden"
        );
        assert.ok(
          visible(".onebox[src='/images/d-logo-sketch-small.png']"),
          "second onebox still visible"
        );

        await click(".chat-message-collapser-closed");

        assert.equal(animatedOneboxes.length, 2, "two oneboxes rendered");

        await click(
          document.querySelectorAll(".chat-message-collapser-opened")[1],
          "close second preview"
        );

        assert.ok(
          visible(".onebox[src='/images/avatar.png']"),
          "first onebox still visible"
        );
        assert.notOk(
          visible(".onebox[src='/images/d-logo-sketch-small.png']"),
          "second onebox hidden"
        );

        await click(".chat-message-collapser-closed");

        assert.equal(animatedOneboxes.length, 2, "two oneboxes rendered");
      },
    });
  }
);

module(
  "Discourse Chat | Component | chat message collapser external image onebox",
  function (hooks) {
    setupRenderingTest(hooks);

    componentTest("shows links for animated image", {
      template: hbs`{{chat-message-collapser cooked=cooked}}`,

      beforeEach() {
        this.set("cooked", externalImageCooked);
      },

      async test(assert) {
        const links = document.querySelectorAll(
          "a.chat-message-collapser-link-small"
        );

        assert.ok(links[0].innerText.trim().includes("http://cat1.com"));
        assert.ok(links[0].href.includes("http://cat1.com"));

        assert.ok(links[1].innerText.trim().includes("http://cat2.com"));
        assert.ok(links[1].href.includes("http://cat2.com"));
      },
    });

    componentTest("shows all user written text", {
      template: hbs`{{chat-message-collapser cooked=cooked}}`,

      beforeEach() {
        this.set("cooked", externalImageCooked);
      },

      async test(assert) {
        const text = document.querySelectorAll(".chat-message-collapser p");

        assert.equal(text.length, 5, "shows all written text");
        assert.strictEqual(text[0].innerText, "written text");
        assert.strictEqual(text[2].innerText, "more written text");
        assert.strictEqual(text[4].innerText, "and even more");
      },
    });

    componentTest("collapses and expands image oneboxes", {
      template: hbs`{{chat-message-collapser cooked=cooked}}`,

      beforeEach() {
        this.set("cooked", externalImageCooked);
      },

      async test(assert) {
        const imageOneboxes = document.querySelectorAll(".onebox");

        assert.equal(imageOneboxes.length, 2, "two oneboxes rendered");

        await click(
          document.querySelectorAll(".chat-message-collapser-opened")[0],
          "close first preview"
        );

        assert.notOk(
          visible(".onebox[href='http://cat1.com']"),
          "first onebox hidden"
        );
        assert.ok(
          visible(".onebox[href='http://cat2.com']"),
          "second onebox still visible"
        );

        await click(".chat-message-collapser-closed");

        assert.equal(imageOneboxes.length, 2, "two oneboxes rendered");

        await click(
          document.querySelectorAll(".chat-message-collapser-opened")[1],
          "close second preview"
        );

        assert.ok(
          visible(".onebox[href='http://cat1.com']"),
          "first onebox still visible"
        );
        assert.notOk(
          visible(".onebox[href='http://cat2.com']"),
          "second onebox hidden"
        );

        await click(".chat-message-collapser-closed");

        assert.equal(imageOneboxes.length, 2, "two oneboxes rendered");
      },
    });
  }
);

module(
  "Discourse Chat | Component | chat message collapser images",
  function (hooks) {
    setupRenderingTest(hooks);

    test("escapes link", async function (assert) {
      this.set(
        "cooked",
        imageCooked
          .replace("shows alt", evilString)
          .replace("/images/d-logo-sketch-small.png", evilString)
      );
      await render(hbs`{{chat-message-collapser cooked=cooked}}`);

      assert.ok(
        queryAll(".chat-message-collapser-link-small")[0].innerHTML.includes(
          evilStringEscaped
        )
      );
      assert.ok(
        queryAll(".chat-message-collapser-link-small")[1].innerHTML.includes(
          "%3Cscript%3Esomeeviltitle%3C/script%3E"
        )
      );
    });

    componentTest("shows alt or links (if no alt) for linked image", {
      template: hbs`{{chat-message-collapser cooked=cooked}}`,

      beforeEach() {
        this.set("cooked", imageCooked);
      },

      async test(assert) {
        const links = document.querySelectorAll(
          "a.chat-message-collapser-link-small"
        );

        assert.ok(links[0].innerText.trim().includes("shows alt"));
        assert.ok(links[0].href.includes("/images/avatar.png"));

        assert.ok(
          links[1].innerText.trim().includes("/images/d-logo-sketch-small.png")
        );
        assert.ok(links[1].href.includes("/images/d-logo-sketch-small.png"));
      },
    });

    componentTest("shows all user written text", {
      template: hbs`{{chat-message-collapser cooked=cooked}}`,

      beforeEach() {
        this.set("cooked", imageCooked);
      },

      async test(assert) {
        const text = document.querySelectorAll(".chat-message-collapser p");

        assert.equal(text.length, 6, "shows all written text");
        assert.strictEqual(text[0].innerText, "written text");
        assert.strictEqual(text[2].innerText, "more written text");
        assert.strictEqual(text[4].innerText, "and even more");
      },
    });

    componentTest("collapses and expands images", {
      template: hbs`{{chat-message-collapser cooked=cooked}}`,

      beforeEach() {
        this.set("cooked", imageCooked);
      },

      async test(assert) {
        const images = document.querySelectorAll("img");

        assert.equal(images.length, 3);

        await click(
          document.querySelectorAll(".chat-message-collapser-opened")[0],
          "close first preview"
        );

        assert.notOk(
          visible("img[src='/images/avatar.png']"),
          "first image hidden"
        );
        assert.ok(
          visible("img[src='/images/d-logo-sketch-small.png']"),
          "second image still visible"
        );

        await click(".chat-message-collapser-closed");

        assert.equal(images.length, 3);

        await click(
          document.querySelectorAll(".chat-message-collapser-opened")[1],
          "close second preview"
        );

        assert.ok(
          visible("img[src='/images/avatar.png']"),
          "first image still visible"
        );
        assert.notOk(
          visible("img[src='/images/d-logo-sketch-small.png']"),
          "second image hidden"
        );

        await click(".chat-message-collapser-closed");

        assert.equal(images.length, 3);
      },
    });

    componentTest("does not show collapser for emoji images", {
      template: hbs`{{chat-message-collapser cooked=cooked}}`,

      beforeEach() {
        this.set("cooked", imageCooked);
      },

      async test(assert) {
        const links = document.querySelectorAll(
          "a.chat-message-collapser-link-small"
        );
        const images = document.querySelectorAll("img");
        const collapser = document.querySelectorAll(
          ".chat-message-collapser-opened"
        );

        assert.equal(links.length, 2);
        assert.equal(images.length, 3, "shows images and emoji");
        assert.equal(collapser.length, 2);
      },
    });
  }
);

module(
  "Discourse Chat | Component | chat message collapser galleries",
  function (hooks) {
    setupRenderingTest(hooks);

    test("escapes title/link", async function (assert) {
      this.set(
        "cooked",
        galleryCooked
          .replace("https://imgur.com/gallery/yyVx5lJ", evilString)
          .replace("Le tomtom album", evilString)
      );
      await render(hbs`{{chat-message-collapser cooked=cooked}}`);

      assert.ok(
        query(".chat-message-collapser-link-small").href.includes(
          "%3Cscript%3Esomeeviltitle%3C/script%3E"
        )
      );
      assert.strictEqual(
        query(".chat-message-collapser-link-small").innerHTML.trim(),
        "someeviltitle"
      );
    });

    componentTest("removes album title overlay", {
      template: hbs`{{chat-message-collapser cooked=cooked}}`,

      beforeEach() {
        this.set("cooked", galleryCooked);
      },

      async test(assert) {
        assert.notOk(visible(".album-title"), "album title removed");
      },
    });

    componentTest("shows gallery link", {
      template: hbs`{{chat-message-collapser cooked=cooked}}`,

      beforeEach() {
        this.set("cooked", galleryCooked);
      },

      async test(assert) {
        assert.ok(
          query(".chat-message-collapser-link-small").innerText.includes(
            "Le tomtom album"
          )
        );
      },
    });

    componentTest("shows all user written text", {
      template: hbs`{{chat-message-collapser cooked=cooked}}`,

      beforeEach() {
        this.set("cooked", galleryCooked);
      },

      async test(assert) {
        const text = document.querySelectorAll(".chat-message-collapser p");

        assert.equal(text.length, 2, "shows all written text");
        assert.strictEqual(text[0].innerText, "written text");
        assert.strictEqual(text[1].innerText, "more written text");
      },
    });

    componentTest("collapses and expands images", {
      template: hbs`{{chat-message-collapser cooked=cooked}}`,

      beforeEach() {
        this.set("cooked", galleryCooked);
      },

      async test(assert) {
        assert.ok(visible("img"), "image visible initially");

        await click(
          document.querySelectorAll(".chat-message-collapser-opened")[0],
          "close preview"
        );

        assert.notOk(visible("img"), "image hidden");

        await click(".chat-message-collapser-closed");

        assert.ok(visible("img"), "image visible initially");
      },
    });
  }
);
