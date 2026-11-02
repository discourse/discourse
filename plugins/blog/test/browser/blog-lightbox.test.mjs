import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";
import vm from "node:vm";

const source = readFileSync(
  new URL("../../public/blog.js", import.meta.url),
  "utf8"
);

class Element {
  constructor(tagName) {
    this.tagName = tagName;
    this.attributes = new Map();
    this.children = [];
    this.className = "";
    this.hidden = false;
    this.listeners = new Map();
    this.classList = {
      values: new Set(),
      add: (name) => this.classList.values.add(name),
      contains: (name) => this.classList.values.has(name),
      remove: (name) => this.classList.values.delete(name),
    };
  }

  addEventListener(name, callback) {
    this.listeners.set(name, callback);
  }

  append(...children) {
    this.children.push(...children);
  }

  close() {
    this.open = false;
    this.listeners.get("close")?.({ target: this });
  }

  dispatch(name, attributes = {}) {
    const event = {
      target: this,
      button: 0,
      defaultPrevented: false,
      preventDefault() {
        this.defaultPrevented = true;
      },
      ...attributes,
    };
    this.listeners.get(name)?.(event);
    return event;
  }

  focus() {
    this.focused = true;
  }

  removeAttribute(name) {
    this.attributes.delete(name);
    if (name === "src") {
      this.src = "";
    } else if (name === "href") {
      this.href = "";
    }
  }

  setAttribute(name, value) {
    this.attributes.set(name, value);
  }

  showModal() {
    this.open = true;
  }
}

function buildImage({ alt, link, sourceUrl, title = "", excluded = false }) {
  const image = new Element("img");
  image.alt = alt;
  image.currentSrc = sourceUrl;
  image.src = sourceUrl;
  image.title = title;
  image.matches = () => false;
  image.closest = (selector) => {
    if (selector === "aside.onebox, a.video-thumbnail") {
      return excluded ? {} : null;
    }
    if (selector === "a") {
      return link;
    }
  };
  return image;
}

function loadLightbox(images) {
  const body = new Element("body");
  body.dataset = {
    blogLightboxCloseLabel: "Close translated",
    blogLightboxDialogLabel: "Dialog translated",
    blogLightboxOpenLabel: "Open translated",
    blogLightboxOpenWithDescriptionLabel:
      "Translated description __IMAGE_DESCRIPTION__",
    blogLightboxOriginalLabel: "Original translated",
  };
  const article = { querySelectorAll: () => images };
  const document = {
    body,
    createElement: (tagName) => new Element(tagName),
    getElementById: () => null,
    querySelector: (selector) =>
      selector === ".blog-article__body" ? article : null,
  };

  vm.runInNewContext(source, { document });

  return { body };
}

test("opens bare article images in a translated accessible dialog", () => {
  const image = buildImage({
    alt: "A useful diagram",
    sourceUrl: "https://example.com/diagram.jpg",
  });
  const excluded = buildImage({
    alt: "Preview thumbnail",
    excluded: true,
    sourceUrl: "https://example.com/preview.jpg",
  });
  const { body } = loadLightbox([image, excluded]);

  assert.equal(image.attributes.get("role"), "button");
  assert.equal(
    image.attributes.get("aria-label"),
    "Translated description A useful diagram"
  );
  assert.ok(image.classList.contains("blog-lightbox-trigger"));
  assert.ok(!excluded.classList.contains("blog-lightbox-trigger"));

  image.currentSrc = "https://example.com/responsive-diagram.jpg";
  image.dispatch("click");
  const dialog = body.children[0];
  const [controls, figure] = dialog.children;
  const [original, close] = controls.children;
  const [largeImage, caption] = figure.children;
  assert.ok(dialog.open);
  assert.equal(dialog.attributes.get("aria-label"), "Dialog translated");
  assert.equal(original.href, image.currentSrc);
  assert.equal(original.textContent, "Original translated");
  assert.equal(original.target, "_blank");
  assert.equal(original.rel, "noopener");
  assert.equal(close.attributes.get("aria-label"), "Close translated");
  assert.ok(close.autofocus);
  assert.equal(close.children[0].attributes.get("aria-hidden"), "true");
  assert.equal(largeImage.src, image.currentSrc);
  assert.equal(largeImage.alt, image.alt);
  assert.ok(caption.hidden);
  assert.ok(body.classList.contains("has-blog-lightbox"));

  dialog.close();
  assert.ok(image.focused);
  assert.ok(!body.classList.contains("has-blog-lightbox"));
  assert.equal(largeImage.src, "");
  assert.equal(original.href, "");
});

test("uses the original cooked upload and treats its caption as text", () => {
  const link = new Element("a");
  link.href = "https://example.com/original.jpg";
  link.title = "<strong>Plain caption</strong>";
  link.classList.add("lightbox");
  const image = buildImage({
    alt: "Uploaded photograph",
    link,
    sourceUrl: "https://example.com/thumbnail.jpg",
  });
  const { body } = loadLightbox([image]);

  const modifiedClick = link.dispatch("click", { ctrlKey: true });
  assert.ok(!modifiedClick.defaultPrevented);
  assert.equal(body.children.length, 0);

  const click = link.dispatch("click");
  assert.ok(click.defaultPrevented);
  const dialog = body.children[0];
  const [largeImage, caption] = dialog.children[1].children;
  assert.equal(largeImage.src, link.href);
  assert.equal(caption.textContent, link.title);
  assert.ok(!caption.hidden);
});
