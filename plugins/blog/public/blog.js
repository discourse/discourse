const comments = document.getElementById("discourse-comments");

if (comments) {
  const loadDiscussion = () => {
    const discussion = comments.closest(".blog-discussion");
    discussion.classList.add("is-loading");
    const failure = discussion.querySelector(".blog-discussion__load-error");
    const failDiscussion = () => {
      discussion.classList.remove("is-loading");
      discussion.classList.add("is-failed");
      failure.hidden = false;
      window.removeEventListener("message", handleDiscussionMessage);
      clearTimeout(timeout);
    };
    const discussOrigin = new URL(comments.dataset.discourseUrl).origin;
    // The embed cannot read the reader palette, so send it the colours it needs.
    const sendPalette = () => {
      const styles = getComputedStyle(document.documentElement);
      const frame = document.getElementById("discourse-embed-frame");
      frame?.contentWindow?.postMessage(
        {
          type: "discourse-blog-palette",
          accent: styles.getPropertyValue("--blog-accent-color").trim(),
          paper: styles.getPropertyValue("--blog-paper-color").trim(),
          ink: styles.getPropertyValue("--blog-ink-color").trim(),
        },
        discussOrigin
      );
    };
    const timeout = setTimeout(failDiscussion, 30000);
    const handleDiscussionMessage = (event) => {
      const frame = document.getElementById("discourse-embed-frame");
      if (
        event.origin !== discussOrigin ||
        event.source !== frame?.contentWindow
      ) {
        return;
      }
      if (event.data?.type === "discourse-blog-resize") {
        const height = event.data.height;
        if (
          typeof height === "number" &&
          Number.isFinite(height) &&
          height > 0
        ) {
          // Leave a pixel for fractional layout rounding at non-default zoom levels.
          frame.style.height = `${Math.max(280, Math.ceil(height) + 1)}px`;
          frame.scrolling = "auto";
        }
      } else if (event.data?.type === "discourse-blog-ready") {
        clearTimeout(timeout);
        discussion.classList.remove("is-loading");
        sendPalette();
      }
    };
    window.addEventListener("message", handleDiscussionMessage);

    window.DiscourseEmbed = {
      discourseUrl: comments.dataset.discourseUrl,
      topicId: Number(comments.dataset.topicId),
      fullApp: true,
      className: "discourse-blog-discussion",
      embedHeight: "320px",
      dynamicHeight: false,
      embedMinHeight: 280,
      lazyLoad: false,
      discourseReferrerPolicy: "strict-origin-when-cross-origin",
    };
    const script = document.createElement("script");
    script.src = `${comments.dataset.discourseUrl}javascripts/embed.js`;
    script.onerror = failDiscussion;
    script.onload = () => {
      const frame = document.getElementById("discourse-embed-frame");
      if (frame) {
        frame.title = comments.dataset.title;
        frame.scrolling = "auto";
      }
    };
    document.head.appendChild(script);
  };

  const observer = new IntersectionObserver(
    (entries) => {
      if (entries.some((entry) => entry.isIntersecting)) {
        observer.disconnect();
        loadDiscussion();
      }
    },
    { rootMargin: "300px" }
  );
  observer.observe(comments);
}

const article = document.querySelector?.(".blog-article__body");

if (article && document.body.dataset.blogHighlightCoreUrl) {
  const blocks = [...article.querySelectorAll("pre code")]
    .map((code) => {
      const language = [...code.classList]
        .map((name) => name.match(/^lang(?:uage)?-(.+)$/i)?.[1])
        .find(Boolean)
        ?.toLowerCase();
      return { code, language };
    })
    .filter(({ code, language }) => {
      return (
        !code.dataset.highlighted &&
        !code.closest(".nohighlight, .no-highlight") &&
        !/^(text|plaintext|plain|none|nohighlight|no-highlight)$/.test(
          language
        ) &&
        (language || document.body.dataset.blogHighlightAuto === "true") &&
        code.textContent.length <= 30000
      );
    });

  if (blocks.length) {
    const highlight = async () => {
      try {
        const [{ default: hljs }, { default: registerLanguages }] =
          await Promise.all([
            import(document.body.dataset.blogHighlightCoreUrl),
            import(document.body.dataset.blogHighlightLanguagesUrl),
          ]);
        registerLanguages(hljs);

        for (const { code, language } of blocks) {
          const lines = [...code.querySelectorAll("ol.lines > li")];
          if (!lines.length && code.children.length) {
            continue;
          }

          const text = lines.length
            ? lines.map((line) => line.textContent).join("\n")
            : code.textContent;
          const detected =
            !language || language === "auto"
              ? hljs.highlightAuto(text.trimStart().slice(0, 2000)).language
              : language;
          if (!detected || !hljs.getLanguage(detected)) {
            continue;
          }

          const highlighted = document.createElement("code");
          highlighted.className = `language-${detected}`;
          highlighted.textContent = text;
          hljs.highlightElement(highlighted);

          if (lines.length) {
            // Highlight the whole snippet so multiline tokens retain their context.
            const fragments = lines.map(() =>
              document.createDocumentFragment()
            );
            const walker = document.createTreeWalker(
              highlighted,
              NodeFilter.SHOW_TEXT
            );
            let lineIndex = 0;
            while (walker.nextNode()) {
              const node = walker.currentNode;
              for (const [index, part] of node.textContent
                .split("\n")
                .entries()) {
                if (index) {
                  lineIndex++;
                }
                let token = document.createTextNode(part);
                for (
                  let parent = node.parentNode;
                  parent !== highlighted;
                  parent = parent.parentNode
                ) {
                  const wrapper = parent.cloneNode(false);
                  wrapper.append(token);
                  token = wrapper;
                }
                fragments[lineIndex].append(token);
              }
            }
            lines.forEach((line, index) =>
              line.replaceChildren(fragments[index])
            );
          } else {
            code.replaceChildren(...highlighted.childNodes);
          }
          code.classList.add("hljs");
          code.dataset.highlighted = "yes";
        }
      } catch (error) {
        // eslint-disable-next-line no-console
        console.warn("Could not load blog syntax highlighting", error);
      }
    };

    if (window.requestIdleCallback) {
      window.requestIdleCallback(highlight, { timeout: 2000 });
    } else {
      setTimeout(highlight, 0);
    }
  }
}

if (article) {
  const probe = document.createElement("dialog");

  if (typeof probe.showModal === "function") {
    const images = article.querySelectorAll("img");
    const openLabel = document.body.dataset.blogLightboxOpenLabel;
    const openWithDescriptionLabel =
      document.body.dataset.blogLightboxOpenWithDescriptionLabel;
    const closeLabel = document.body.dataset.blogLightboxCloseLabel;
    const dialogLabel = document.body.dataset.blogLightboxDialogLabel;
    const originalLabel = document.body.dataset.blogLightboxOriginalLabel;
    let dialog;
    let dialogCaption;
    let dialogImage;
    let dialogOriginal;
    let lastTrigger;

    const ensureDialog = () => {
      if (dialog) {
        return;
      }

      dialog = probe;
      dialog.className = "blog-lightbox";
      dialog.setAttribute("aria-label", dialogLabel);

      dialogOriginal = document.createElement("a");
      dialogOriginal.className = "blog-lightbox__original";
      dialogOriginal.target = "_blank";
      dialogOriginal.rel = "noopener";
      dialogOriginal.textContent = originalLabel;

      const close = document.createElement("button");
      close.type = "button";
      close.autofocus = true;
      close.className = "blog-lightbox__close";
      close.setAttribute("aria-label", closeLabel);
      const closeIcon = document.createElement("span");
      closeIcon.className = "blog-lightbox__close-icon";
      closeIcon.setAttribute("aria-hidden", "true");
      close.append(closeIcon);
      close.addEventListener("click", () => dialog.close());

      const controls = document.createElement("div");
      controls.className = "blog-lightbox__controls";
      controls.append(dialogOriginal, close);

      const figure = document.createElement("figure");
      figure.className = "blog-lightbox__figure";
      dialogImage = document.createElement("img");
      dialogImage.className = "blog-lightbox__image";
      dialogCaption = document.createElement("figcaption");
      dialogCaption.className = "blog-lightbox__caption";
      figure.append(dialogImage, dialogCaption);
      dialog.append(controls, figure);
      document.body.append(dialog);

      dialog.addEventListener("click", (event) => {
        if (event.target === dialog) {
          dialog.close();
        }
      });
      dialog.addEventListener("close", () => {
        document.body.classList.remove("has-blog-lightbox");
        dialogImage.removeAttribute("src");
        dialogOriginal.removeAttribute("href");
        lastTrigger?.focus();
      });
    };

    const openLightbox = (trigger, image, source) => {
      if (!source) {
        return;
      }

      ensureDialog();
      lastTrigger = trigger;
      dialogImage.src = source;
      dialogImage.alt = image.alt;
      dialogOriginal.href = source;
      const caption = trigger.title || image.title;
      dialogCaption.textContent = caption;
      dialogCaption.hidden = !caption;
      document.body.classList.add("has-blog-lightbox");
      dialog.showModal();
    };

    for (const image of images) {
      if (
        image.matches(".emoji, .avatar, .site-icon") ||
        image.closest("aside.onebox, a.video-thumbnail")
      ) {
        continue;
      }

      const imageLink = image.closest("a");
      if (imageLink && !imageLink.classList.contains("lightbox")) {
        continue;
      }

      const trigger = imageLink || image;
      const source = () => imageLink?.href || image.currentSrc || image.src;
      if (!source()) {
        continue;
      }

      trigger.classList.add("blog-lightbox-trigger");
      trigger.setAttribute("aria-haspopup", "dialog");

      if (!imageLink) {
        trigger.tabIndex = 0;
        trigger.setAttribute("role", "button");
        trigger.setAttribute(
          "aria-label",
          image.alt
            ? openWithDescriptionLabel.replace(
                "__IMAGE_DESCRIPTION__",
                image.alt
              )
            : openLabel
        );
      }

      trigger.addEventListener("click", (event) => {
        if (
          event.defaultPrevented ||
          event.button !== 0 ||
          event.altKey ||
          event.ctrlKey ||
          event.metaKey ||
          event.shiftKey
        ) {
          return;
        }

        event.preventDefault();
        openLightbox(trigger, image, source());
      });

      if (!imageLink) {
        trigger.addEventListener("keydown", (event) => {
          if (event.key === "Enter" || event.key === " ") {
            event.preventDefault();
            openLightbox(trigger, image, source());
          }
        });
      }
    }
  }
}
