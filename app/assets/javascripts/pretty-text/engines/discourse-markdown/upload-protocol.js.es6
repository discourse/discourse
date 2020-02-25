// add image to array if src has an upload
function addImage(uploads, token) {
  if (token.attrs) {
    for (let i = 0; i < token.attrs.length; i++) {
      if (token.attrs[i][1].indexOf("upload://") === 0) {
        uploads.push([token, i]);
        break;
      }
    }
  }
}

function rule(state) {
  let uploads = [];

  for (let i = 0; i < state.tokens.length; i++) {
    let blockToken = state.tokens[i];

    if (blockToken.tag === "img" || blockToken.tag === "a") {
      addImage(uploads, blockToken);
    }

    if (!blockToken.children) continue;

    for (let j = 0; j < blockToken.children.length; j++) {
      let token = blockToken.children[j];

      if (token.tag === "img" || token.tag === "a") addImage(uploads, token);
    }
  }

  if (uploads.length > 0) {
    let srcList = uploads.map(([token, srcIndex]) => token.attrs[srcIndex][1]);
    let lookup = state.md.options.discourse.lookupUploadUrls;
    let longUrls = (lookup && lookup(srcList)) || {};

    uploads.forEach(([token, srcIndex]) => {
      let origSrc = token.attrs[srcIndex][1];
      let mapped = longUrls[origSrc];

      switch (token.tag) {
        case "img":
          if (mapped) {
            token.attrs[srcIndex][1] = mapped.url;
            token.attrs.push(["data-base62-sha1", mapped.base62_sha1]);
          } else {
            // no point putting a transparent .png for audio/video
            if (token.content.match(/\|video|\|audio/)) {
              token.attrs[srcIndex][1] = state.md.options.discourse.getURL(
                "/404"
              );
            } else {
              token.attrs[srcIndex][1] = state.md.options.discourse.getURL(
                "/images/transparent.png"
              );
            }

            token.attrs.push(["data-orig-src", origSrc]);
          }
          break;
        case "a":
          if (mapped) {
            token.attrs[srcIndex][1] = mapped.short_path;
          } else {
            token.attrs[srcIndex][1] = state.md.options.discourse.getURL(
              "/404"
            );

            token.attrs.push(["data-orig-href", origSrc]);
          }

          break;
      }
    });
  }
}

export function setup(helper) {
  const opts = helper.getOptions();
  if (opts.previewing) helper.whiteList(["img.resizable"]);

  helper.whiteList([
    "img[data-orig-src]",
    "img[data-base62-sha1]",
    "a[data-orig-href]"
  ]);

  helper.registerPlugin(md => {
    md.core.ruler.push("upload-protocol", rule);
  });
}
