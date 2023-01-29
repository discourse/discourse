import xss from "xss";

const HTML_TYPES = ["html_block", "html_inline"];

// add image to array if src has an upload
function addImage(uploads, token) {
  if (token.attrs) {
    for (let i = 0; i < token.attrs.length; i++) {
      const value = token.attrs[i][1];
      if (value?.startsWith("upload://")) {
        uploads.push({ token, srcIndex: i, origSrc: value });
        break;
      }
    }
  }
}

function attr(name, value) {
  if (value) {
    return `${name}="${xss.escapeAttrValue(value)}"`;
  }

  return name;
}

function uploadLocatorString(url) {
  return `___REPLACE_UPLOAD_SRC_${url}___`;
}

function findUploadsInHtml(uploads, blockToken) {
  // Slightly misusing our HTML sanitizer to look for upload://
  // image src attributes, and replace them with a placeholder.
  // Note that we can't use browser DOM APIs because this needs
  // to run in mini-racer.
  let foundImage = false;
  let allowList;

  const filter = new xss.FilterXSS({
    allowList: [],
    allowCommentTag: true,
    onTag(tag, html, info) {
      // We're not using this for sanitizing, so allow all tags through
      info.isWhite = true;
      allowList[tag] = [];
    },
    onTagAttr(tag, name, value) {
      if (tag === "img" && name === "src" && value.startsWith("upload://")) {
        uploads.push({ token: blockToken, srcIndex: null, origSrc: value });
        foundImage = true;
        return uploadLocatorString(value);
      }
      return attr(name, value);
    },
  });

  allowList = filter.options.whiteList;
  const newContent = filter.process(blockToken.content);

  if (foundImage) {
    blockToken.content = newContent;
  }
}

function processToken(uploads, token) {
  if (token.tag === "img" || token.tag === "a") {
    addImage(uploads, token);
  } else if (HTML_TYPES.includes(token.type)) {
    findUploadsInHtml(uploads, token);
  }

  if (token.children) {
    for (let j = 0; j < token.children.length; j++) {
      const childToken = token.children[j];
      processToken(uploads, childToken);
    }
  }
}

function rule(state) {
  let uploads = [];

  for (let i = 0; i < state.tokens.length; i++) {
    let blockToken = state.tokens[i];

    processToken(uploads, blockToken);
  }

  if (uploads.length > 0) {
    let srcList = uploads.map((u) => u.origSrc);

    // In client-side cooking, this lookup returns nothing
    // This means we set data-orig-src, and let decorateCooked
    // lookup the image URLs asynchronously
    let lookup = state.md.options.discourse.lookupUploadUrls;
    let longUrls = (lookup && lookup(srcList)) || {};

    uploads.forEach(({ token, srcIndex, origSrc }) => {
      let mapped = longUrls[origSrc];

      if (HTML_TYPES.includes(token.type)) {
        const locator = uploadLocatorString(origSrc);
        let attrs = [];

        if (mapped) {
          attrs.push(
            attr("src", mapped.url),
            attr("data-base62-sha1", mapped.base62_sha1)
          );
        } else {
          attrs.push(
            attr(
              "src",
              state.md.options.discourse.getURL("/images/transparent.png")
            ),
            attr("data-orig-src", origSrc)
          );
        }

        token.content = token.content.replace(locator, attrs.join(" "));
      } else if (token.tag === "img") {
        if (mapped) {
          token.attrs[srcIndex][1] = mapped.url;
          token.attrs.push(["data-base62-sha1", mapped.base62_sha1]);
        } else {
          // no point putting a transparent .png for audio/video
          if (token.content.match(/\|video|\|audio/)) {
            token.attrs[srcIndex][1] =
              state.md.options.discourse.getURL("/404");
          } else {
            token.attrs[srcIndex][1] = state.md.options.discourse.getURL(
              "/images/transparent.png"
            );
          }

          token.attrs.push(["data-orig-src", origSrc]);
        }
      } else if (token.tag === "a") {
        if (mapped) {
          // when secure uploads is enabled we want the full /secure-media-uploads or /secure-uploads
          // url to take advantage of access control security
          if (
            state.md.options.discourse.limitedSiteSettings.secureUploads &&
            (mapped.url.includes("secure-media-uploads") ||
              mapped.url.includes("secure-uploads"))
          ) {
            token.attrs[srcIndex][1] = mapped.url;
          } else {
            token.attrs[srcIndex][1] = mapped.short_path;
          }
        } else {
          token.attrs[srcIndex][1] = state.md.options.discourse.getURL("/404");

          token.attrs.push(["data-orig-href", origSrc]);
        }
      }
    });
  }
}

export function setup(helper) {
  const opts = helper.getOptions();
  if (opts.previewing) {
    helper.allowList(["img.resizable"]);
  }

  helper.allowList([
    "img[data-orig-src]",
    "img[data-base62-sha1]",
    "a[data-orig-href]",
  ]);

  helper.registerPlugin((md) => {
    md.core.ruler.push("upload-protocol", rule);
  });
}
