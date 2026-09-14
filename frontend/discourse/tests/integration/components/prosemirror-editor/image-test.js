import { click, find, settled } from "@ember/test-helpers";
import { NodeSelection, TextSelection } from "prosemirror-state";
import { module, test } from "qunit";
import sinon from "sinon";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import {
  setupRichEditor,
  testRenderedMarkdown,
} from "discourse/tests/helpers/rich-editor-helper";
import { i18n } from "discourse-i18n";

// Dragging an image exposes it as a file, as the browser does.
function dragEvent(type, target) {
  const dataTransfer = new DataTransfer();
  dataTransfer.items.add(new File(["x"], "image.png", { type: "image/png" }));
  target.dispatchEvent(
    new DragEvent(type, { dataTransfer, bubbles: true, cancelable: true })
  );
}

function requestedShortUrls(request) {
  return new URLSearchParams(request.requestBody).getAll("short_urls[]");
}

function videoLookupResponse(request, base62Sha1, extension = "mp4") {
  const urls = requestedShortUrls(request);
  const uploads = [
    {
      short_url: `upload://${base62Sha1}.${extension}`,
      url: `/uploads/video.${extension}`,
    },
    {
      short_url: `upload://${base62Sha1}`,
      url: "/uploads/video-thumbnail.png",
    },
  ];

  return response(uploads.filter((upload) => urls.includes(upload.short_url)));
}

module(
  "Integration | Component | prosemirror-editor - image extension",
  function (hooks) {
    setupRenderingTest(hooks);

    test(
      "basic image",
      testRenderedMarkdown(
        "![alt text](https://example.com/image.jpg)",
        (assert) => {
          assert.dom("img").exists("Image should exist");
          assert
            .dom("img")
            .hasAttribute("src", "https://example.com/image.jpg");
          assert.dom("img").hasAttribute("alt", "alt text");
        }
      )
    );

    test(
      "image with title",
      testRenderedMarkdown(
        '![alt text](https://example.com/image.jpg "title")',
        (assert) => {
          assert.dom("img").exists("Image should exist");
          assert
            .dom("img")
            .hasAttribute("src", "https://example.com/image.jpg");
          assert.dom("img").hasAttribute("alt", "alt text");
          assert.dom("img").hasAttribute("title", "title");
        }
      )
    );

    test(
      "image with dimensions and title",
      testRenderedMarkdown(
        '![alt text|100x200](https://example.com/image.jpg "title")',
        (assert) => {
          assert.dom("img").exists("Image should exist");
          assert
            .dom("img")
            .hasAttribute("src", "https://example.com/image.jpg");
          assert.dom("img").hasAttribute("alt", "alt text");
          assert.dom("img").hasAttribute("title", "title");
          assert.dom("img").hasAttribute("width", "100");
          assert.dom("img").hasAttribute("height", "200");
        }
      )
    );

    test(
      "image with dimensions and scale",
      testRenderedMarkdown(
        "![alt text|100x200, 50%](https://example.com/image.jpg)",
        (assert) => {
          assert.dom("img").exists("Image should exist");
          assert
            .dom("img")
            .hasAttribute("src", "https://example.com/image.jpg");
          assert.dom("img").hasAttribute("alt", "alt text");
          assert.dom("img").hasAttribute("width", "100");
          assert.dom("img").hasAttribute("height", "200");
          assert.dom("img").hasAttribute("data-scale", "50");

          // Check style attribute directly
          const img = document.querySelector("img");
          assert.strictEqual(
            img.style.width,
            "50px",
            "Image width style should be 50px"
          );
        }
      )
    );

    test(
      "image with dimensions, scale and thumbnail",
      testRenderedMarkdown(
        "![alt text|100x200, 50%|thumbnail](https://example.com/image.jpg)",
        (assert) => {
          assert.dom("img").exists("Image should exist");
          assert
            .dom("img")
            .hasAttribute("src", "https://example.com/image.jpg");
          assert.dom("img").hasAttribute("alt", "alt text");
          assert.dom("img").hasAttribute("width", "100");
          assert.dom("img").hasAttribute("height", "200");
          assert.dom("img").hasAttribute("data-scale", "50");
          assert.dom("img").hasAttribute("data-thumbnail", "true");

          // Check style attribute directly
          const img = document.querySelector("img");
          assert.strictEqual(
            img.style.width,
            "50px",
            "Image width style should be 50px"
          );
        }
      )
    );

    test(
      "image with parentheses in URL",
      testRenderedMarkdown(
        "![alt text](https://example.com/image\\(1\\).jpg)",
        (assert) => {
          assert.dom("img").exists("Image should exist");
          assert
            .dom("img")
            .hasAttribute("src", "https://example.com/image(1).jpg");
          assert.dom("img").hasAttribute("alt", "alt text");
        }
      )
    );

    test("video player resolves its video and poster", async function (assert) {
      const markdown = "![Screen Recording|video](upload://videoHash.MOV)";
      let shortUrls;
      pretender.post("/uploads/lookup-urls", (request) => {
        shortUrls = requestedShortUrls(request);
        return videoLookupResponse(request, "videoHash", "MOV");
      });

      const [editor] = await setupRichEditor(assert, markdown);

      assert
        .dom(".composer-video-node video")
        .doesNotHaveAttribute(
          "src",
          "the video source is not loaded before playback is requested"
        );
      assert
        .dom(".composer-video-node video")
        .hasAttribute(
          "poster",
          "/uploads/video-thumbnail.png",
          "the generated thumbnail is shown"
        );
      assert
        .dom(".composer-video-node video")
        .hasAttribute("controls", "", "native playback controls are available");
      assert
        .dom(".composer-video-node video")
        .hasAttribute(
          "aria-label",
          "Screen Recording",
          "the video keeps its label"
        );
      assert
        .dom(".composer-video-node__play")
        .exists("a prominent play control is available");
      assert.deepEqual(
        shortUrls,
        ["upload://videoHash.MOV", "upload://videoHash"],
        "the video and extensionless thumbnail URLs are requested"
      );
      assert.strictEqual(
        editor.value,
        markdown,
        "rendering the player preserves the markdown"
      );
    });

    test("video player ignores a poster that resolves to the video", async function (assert) {
      // With no generated thumbnail, the extensionless short URL resolves to
      // the video upload itself.
      const videoUrl = "/uploads/video.mp4";
      pretender.post("/uploads/lookup-urls", (request) =>
        response(
          requestedShortUrls(request).map((short_url) => ({
            short_url,
            url: videoUrl,
          }))
        )
      );

      await setupRichEditor(
        assert,
        "![alt text|video](upload://posterlessHash.mp4)"
      );

      assert
        .dom(".composer-video-node video")
        .doesNotHaveAttribute(
          "poster",
          "the video is not used as its own poster"
        );
      assert
        .dom(".composer-video-node__error")
        .doesNotExist("a missing thumbnail is not an error");
    });

    test("video player can be selected before and after playback", async function (assert) {
      pretender.post("/uploads/lookup-urls", (request) =>
        videoLookupResponse(request, "selectableVideoHash")
      );
      const [editor] = await setupRichEditor(
        assert,
        "![alt text|video](upload://selectableVideoHash.mp4)"
      );
      const video = find(".composer-video-node video");
      let videoClicks = 0;
      let played = false;
      video.addEventListener("click", () => videoClicks++);
      video.play = () => {
        played = true;
        video.dispatchEvent(new Event("playing"));
        return Promise.resolve();
      };

      editor.view.dispatch(
        editor.view.state.tr.setSelection(
          TextSelection.create(editor.view.state.doc, 2)
        )
      );
      await click(".composer-video-node");

      assert.true(
        editor.view.state.selection instanceof NodeSelection,
        "clicking the player selects the video node"
      );
      assert.false(played, "selecting the video does not start playback");
      assert.strictEqual(
        getComputedStyle(video).pointerEvents,
        "none",
        "the paused video leaves pointer handling to the editor"
      );

      editor.view.dispatch(
        editor.view.state.tr.setSelection(
          TextSelection.create(editor.view.state.doc, 2)
        )
      );
      await click(".composer-video-node__play");
      editor.view.dispatch(
        editor.view.state.tr.setSelection(
          TextSelection.create(editor.view.state.doc, 2)
        )
      );
      await click(".composer-video-node video");

      assert.true(
        editor.view.state.selection instanceof NodeSelection,
        "clicking the video selects it after playback"
      );
      assert.strictEqual(
        videoClicks,
        1,
        "selection does not consume the video's click behavior"
      );
    });

    test("video play control tracks playback", async function (assert) {
      pretender.post("/uploads/lookup-urls", (request) =>
        videoLookupResponse(request, "playableVideoHash")
      );
      const [editor] = await setupRichEditor(
        assert,
        "![alt text|video](upload://playableVideoHash.mp4)"
      );

      let played = false;
      const video = find(".composer-video-node video");

      video.play = () => {
        assert.strictEqual(
          video.getAttribute("src"),
          "/uploads/video.mp4",
          "the source is rendered only when playback is requested"
        );
        played = true;
        video.dispatchEvent(new Event("play"));
        return Promise.resolve();
      };

      editor.view.dispatch(
        editor.view.state.tr.setSelection(
          TextSelection.create(editor.view.state.doc, 2)
        )
      );

      await click(".composer-video-node__play");

      assert.true(played, "the prominent play control starts playback");
      assert.false(
        editor.view.state.selection instanceof NodeSelection,
        "playing the video does not select it"
      );
      assert
        .dom(".composer-video-node__play")
        .exists("the prominent play control remains until playback begins");

      video.dispatchEvent(new Event("playing"));
      await settled();

      assert
        .dom(".composer-video-node__play")
        .doesNotExist("the prominent play control is hidden during playback");
      assert.strictEqual(
        getComputedStyle(video).pointerEvents,
        "auto",
        "native controls are interactive during playback"
      );

      video.dispatchEvent(new Event("pause"));
      await settled();

      assert
        .dom(".composer-video-node__play")
        .doesNotExist("pausing does not replace the native controls");
      assert.strictEqual(
        getComputedStyle(video).pointerEvents,
        "auto",
        "native controls remain interactive while paused"
      );
    });

    test("video player keeps stable 16:9 geometry", async function (assert) {
      pretender.post("/uploads/lookup-urls", (request) =>
        videoLookupResponse(request, "geometryVideoHash")
      );
      await setupRichEditor(
        assert,
        "![alt text|video](upload://geometryVideoHash.mp4)"
      );

      const player = find(".composer-video-node");
      const video = find(".composer-video-node video");
      const initialPlayerRect = player.getBoundingClientRect();
      const videoRect = video.getBoundingClientRect();

      assert.true(initialPlayerRect.width > 0, "the player has positive width");
      assert.true(
        initialPlayerRect.height > 0,
        "the player has positive height"
      );
      assert.true(
        Math.abs(initialPlayerRect.width / initialPlayerRect.height - 16 / 9) <
          0.01,
        "the player uses a 16:9 aspect ratio"
      );
      assert.propEqual(
        {
          bottom: videoRect.bottom,
          left: videoRect.left,
          right: videoRect.right,
          top: videoRect.top,
        },
        {
          bottom: initialPlayerRect.bottom,
          left: initialPlayerRect.left,
          right: initialPlayerRect.right,
          top: initialPlayerRect.top,
        },
        "the video fills the player"
      );

      video.dispatchEvent(new Event("playing"));
      await settled();

      const playingPlayerRect = player.getBoundingClientRect();
      assert.strictEqual(
        playingPlayerRect.width,
        initialPlayerRect.width,
        "playback does not change the player width"
      );
      assert.strictEqual(
        playingPlayerRect.height,
        initialPlayerRect.height,
        "playback does not change the player height"
      );
    });

    test("video URL lookup failures can be retried", async function (assert) {
      const announce = sinon.spy(this.owner.lookup("service:a11y"), "announce");
      let lookupCount = 0;
      pretender.post("/uploads/lookup-urls", (request) => {
        lookupCount++;
        return lookupCount === 1
          ? response([])
          : videoLookupResponse(request, "retryVideoHash");
      });
      await setupRichEditor(
        assert,
        "![alt text|video](upload://retryVideoHash.mp4)"
      );
      const video = find(".composer-video-node video");
      let played = false;
      video.play = () => {
        assert.strictEqual(
          video.getAttribute("src"),
          "/uploads/video.mp4",
          "the resolved source is rendered before playback starts"
        );
        played = true;
        video.dispatchEvent(new Event("playing"));
        return Promise.resolve();
      };

      assert
        .dom(".composer-video-node__error")
        .hasText(i18n("invalid_video_url"), "the lookup error is displayed");
      assert.true(
        announce.calledWith(i18n("invalid_video_url"), "polite"),
        "the background lookup failure is announced politely"
      );

      await click(".composer-video-node__play");

      assert.strictEqual(lookupCount, 2, "the play control retries the lookup");
      assert.true(played, "the same click plays the resolved video");
      assert
        .dom(".composer-video-node__error")
        .doesNotExist("the lookup error is cleared after retrying");
      assert
        .dom(".composer-video-node video")
        .hasAttribute(
          "src",
          "/uploads/video.mp4",
          "the retry resolves the video"
        );
    });

    test("video playback failures are displayed", async function (assert) {
      const announce = sinon.spy(this.owner.lookup("service:a11y"), "announce");
      pretender.post("/uploads/lookup-urls", (request) =>
        videoLookupResponse(request, "brokenVideoHash")
      );
      await setupRichEditor(
        assert,
        "![alt text|video](upload://brokenVideoHash.mp4)"
      );
      const video = find(".composer-video-node video");
      video.play = () => Promise.reject();

      await click(".composer-video-node__play");

      assert
        .dom(".composer-video-node__error")
        .hasText(
          i18n("cannot_render_video"),
          "the playback error is displayed"
        );
      assert.true(
        announce.calledWith(i18n("cannot_render_video"), "assertive"),
        "the user-triggered playback failure is announced assertively"
      );

      video.dispatchEvent(new Event("error"));
      await settled();

      assert.strictEqual(
        announce.callCount,
        1,
        "the same playback failure is not announced twice"
      );
    });

    test("pending playback failures are ignored after teardown", async function (assert) {
      const announce = sinon.spy(this.owner.lookup("service:a11y"), "announce");
      pretender.post("/uploads/lookup-urls", (request) =>
        videoLookupResponse(request, "removedVideoHash")
      );
      const [editor] = await setupRichEditor(
        assert,
        "![alt text|video](upload://removedVideoHash.mp4)"
      );
      const video = find(".composer-video-node video");
      let markPlaybackStarted;
      let rejectPlayback;
      const playbackStarted = new Promise((resolve) => {
        markPlaybackStarted = resolve;
      });
      video.play = () =>
        new Promise((_resolve, reject) => {
          markPlaybackStarted();
          rejectPlayback = reject;
        });

      const interaction = click(".composer-video-node__play");
      await playbackStarted;
      editor.view.dispatch(editor.view.state.tr.delete(1, 2));
      await settled();
      rejectPlayback();
      await interaction;
      await settled();

      assert.strictEqual(
        announce.callCount,
        0,
        "a removed player does not announce a late playback failure"
      );
    });

    test("round-trips a video through the clipboard", async function (assert) {
      const markdown =
        '![alt text|video](upload://clipboardHash.mp4 "video title")';
      pretender.post("/uploads/lookup-urls", (request) =>
        videoLookupResponse(request, "clipboardHash")
      );
      const [editor] = await setupRichEditor(assert, markdown);
      const { view } = editor;
      const clipboardData = new DataTransfer();

      view.dispatch(
        view.state.tr.setSelection(NodeSelection.create(view.state.doc, 1))
      );
      const { dom, text } = view.serializeForClipboard(
        view.state.selection.content()
      );
      clipboardData.setData("text/html", dom.innerHTML);
      clipboardData.setData("text/plain", text);
      view.dispatch(view.state.tr.deleteSelection());
      view.dom.dispatchEvent(
        new ClipboardEvent("paste", {
          bubbles: true,
          cancelable: true,
          clipboardData,
        })
      );
      await settled();

      assert
        .dom(".composer-video-node video")
        .exists("the pasted video remains in the editor");
      assert.strictEqual(
        editor.value,
        markdown,
        "the pasted video preserves its upload URL"
      );
    });

    test(
      "audio element",
      testRenderedMarkdown("![alt text|audio](upload://hash)", (assert) => {
        assert.dom("audio").exists("Audio element should exist");
        assert.dom("audio").hasAttribute("preload", "metadata");
        assert.dom("audio source").exists("Audio source should exist");
        assert
          .dom("audio source")
          .hasAttribute("data-orig-src", "upload://hash");
      })
    );

    test("upload:// image alt text is preserved verbatim across round-trips", async function (assert) {
      pretender.post("/uploads/lookup-urls", () => response([]));
      await testRenderedMarkdown(
        "![_test_file_|100x100](upload://hash)",
        (a) => {
          a.dom("img").hasAttribute("alt", "_test_file_");
        }
      ).call(this, assert);
    });

    test("dragging an image within the editor is a move, not an upload", async function (assert) {
      this.siteSettings.rich_editor = true;

      const [{ view }] = await setupRichEditor(
        assert,
        "![alt text](https://example.com/image.jpg)"
      );
      const image = view.dom.querySelector("img");
      let reachedUploadTarget = false;
      view.dom.parentElement.addEventListener(
        "drop",
        () => (reachedUploadTarget = true)
      );

      dragEvent("dragstart", image);
      assert.true(!!view.dragging, "the editor owns the drag");

      dragEvent("drop", image);
      assert.false(reachedUploadTarget, "the drop never reaches the uploader");
      assert.strictEqual(view.dragging, null, "the editor handled the move");
    });

    test("a file dropped from outside still reaches the uploader", async function (assert) {
      this.siteSettings.rich_editor = true;

      const [{ view }] = await setupRichEditor(
        assert,
        "![alt text](https://example.com/image.jpg)"
      );
      let reachedUploadTarget = false;
      view.dom.parentElement.addEventListener(
        "drop",
        () => (reachedUploadTarget = true)
      );

      dragEvent("drop", view.dom.querySelector("img"));
      assert.true(reachedUploadTarget, "the drop reaches the uploader");
    });
  }
);
