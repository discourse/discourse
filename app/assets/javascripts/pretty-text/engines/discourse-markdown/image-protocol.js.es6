// add image to array if src has an upload
function addImage(images, token) {
  if (token.attrs) {
    for (let i = 0; i < token.attrs.length; i++) {
      if (token.attrs[i][1].indexOf("upload://") === 0) {
        images.push([token, i]);
        break;
      }
    }
  }
}

function rule(state) {
  let images = [];

  for (let i = 0; i < state.tokens.length; i++) {
    let blockToken = state.tokens[i];

    if (blockToken.tag === "img") {
      addImage(images, blockToken);
    }

    if (!blockToken.children) {
      continue;
    }

    for (let j = 0; j < blockToken.children.length; j++) {
      let token = blockToken.children[j];
      if (token.tag === "img") {
        addImage(images, token);
      }
    }
  }

  if (images.length > 0) {
    let srcList = images.map(([token, srcIndex]) => token.attrs[srcIndex][1]);
    let lookup = state.md.options.discourse.lookupImageUrls;
    let longUrls = (lookup && lookup(srcList)) || {};

    images.forEach(([token, srcIndex]) => {
      let origSrc = token.attrs[srcIndex][1];
      let mapped = longUrls[origSrc];
      if (mapped) {
        token.attrs[srcIndex][1] = mapped;
      } else {
        token.attrs[srcIndex][1] = state.md.options.discourse.getURL(
          "/images/transparent.png"
        );
        token.attrs.push(["data-orig-src", origSrc]);
      }
    });
  }
}

export function setup(helper) {
  helper.whiteList(["img[data-orig-src]"]);
  helper.registerPlugin(md => {
    md.core.ruler.push("image-protocol", rule);
  });
}
