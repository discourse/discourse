function isUpload(token) {
  return token.content.includes("upload://");
}

function hasMetadata(token) {
  return token.content.match(/(\d{1,4}x\d{1,4})/);
}

function buildToken(state, type, tag, klass, nesting) {
  const token = new state.Token(type, tag, nesting);
  token.block = true;
  token.attrs = [["class", klass]];
  return token;
}

function wrapImage(tokens, index, state, imgNumber) {
  const imgToken = tokens[index];
  const sizePart = imgToken.content
    .split("|")
    .find(x => x.match(/\d{1,4}x\d{1,4}(,\s*\d{1,3}%)?/));
  let selectedScale =
    sizePart &&
    sizePart
      .split(",")
      .pop()
      .trim();
  tokens.splice(
    index,
    0,
    buildToken(state, "wrap_image_open", "span", "image-wrapper", 1)
  );

  const newElements = [];
  const btnWrapper = buildToken(
    state,
    "wrap_button_open",
    "span",
    "button-wrapper",
    1
  );
  btnWrapper.attrs.push(["data-image-index", imgNumber]);
  newElements.push(btnWrapper);

  const minimumScale = 50;
  const scales = [100, 75, minimumScale];
  const overwriteScale = !scales.find(scale => `${scale}%` === selectedScale);
  if (overwriteScale) selectedScale = "100%";

  scales.forEach(scale => {
    const scaleText = `${scale}%`;

    const btnClass =
      scaleText === selectedScale ? "scale-btn active" : "scale-btn";
    const scaleBtn = buildToken(
      state,
      "scale_button_open",
      "span",
      btnClass,
      1
    );
    scaleBtn.attrs.push(["data-scale", scale]);
    newElements.push(scaleBtn);

    let textToken = buildToken(state, "text", "", "", 0);
    textToken.content = scaleText;
    newElements.push(textToken);

    newElements.push(buildToken(state, "scale_button_close", "span", "", -1));

    if (scale !== minimumScale) {
      newElements.push(buildToken(state, "separator", "span", "separator", 1));
      let separatorToken = buildToken(state, "text", "", "", 0);
      separatorToken.content = " • ";
      newElements.push(separatorToken);
      newElements.push(buildToken(state, "separator_close", "span", "", -1));
    }
  });
  newElements.push(buildToken(state, "wrap_button_close", "span", "", -1));

  newElements.push(buildToken(state, "wrap_image_close", "span", "", -1));

  const afterImageIndex = index + 2;
  tokens.splice(afterImageIndex, 0, ...newElements);
}

function updateIndexes(indexes, name) {
  indexes[name].push(indexes.current);
  indexes.current++;
}

function wrapImages(tokens, tokenIndexes, state, imgNumberIndexes) {
  //We do this in reverse order because it's easier for #wrapImage to manipulate the tokens array.
  for (let j = tokenIndexes.length - 1; j >= 0; j--) {
    let index = tokenIndexes[j];
    wrapImage(tokens, index, state, imgNumberIndexes.pop());
  }
}

function rule(state) {
  let blockIndexes = [];
  const indexNumbers = { current: 0, blocks: [], childrens: [] };

  for (let i = 0; i < state.tokens.length; i++) {
    let blockToken = state.tokens[i];
    const blockTokenImage = blockToken.tag === "img";

    if (blockTokenImage && isUpload(blockToken) && hasMetadata(blockToken)) {
      blockIndexes.push(i);
      updateIndexes(indexNumbers, "blocks");
    }

    if (!blockToken.children) continue;

    const childrenIndexes = [];
    for (let j = 0; j < blockToken.children.length; j++) {
      let token = blockToken.children[j];
      const childrenImage = token.tag === "img";

      if (childrenImage && isUpload(blockToken) && hasMetadata(token)) {
        childrenIndexes.push(j);
        updateIndexes(indexNumbers, "childrens");
      }
    }

    wrapImages(
      blockToken.children,
      childrenIndexes,
      state,
      indexNumbers.childrens
    );
  }

  wrapImages(state.tokens, blockIndexes, state, indexNumbers.blocks);
}

export function setup(helper) {
  const opts = helper.getOptions();
  if (opts.previewing) {
    helper.whiteList([
      "span.image-wrapper",
      "span.button-wrapper",
      "span[class=scale-btn]",
      "span[class=scale-btn active]",
      "span.separator",
      "span.scale-btn[data-scale]",
      "span.button-wrapper[data-image-index]"
    ]);

    helper.registerPlugin(md => {
      md.core.ruler.after("upload-protocol", "resize-controls", rule);
    });
  }
}
