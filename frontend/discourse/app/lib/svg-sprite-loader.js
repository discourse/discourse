import { ajax } from "discourse/lib/ajax";
import { SVG_NAMESPACE } from "discourse/lib/icon-library";
import loadScript from "discourse/lib/load-script";

const SVG_CONTAINER_ID = "svg-sprites";
const EXTRA_SPRITE_NAME = "extra-icons";

function spriteContainerElement() {
  let spriteContainer = document.getElementById(SVG_CONTAINER_ID);
  if (!spriteContainer) {
    spriteContainer = document.createElement("div");
    spriteContainer.id = SVG_CONTAINER_ID;
    const spriteWrapper = document.querySelector("discourse-assets-icons");
    (spriteWrapper ?? document.body).appendChild(spriteContainer);
  }
  return spriteContainer;
}

/**
 * Whether the page sprite can already render an icon.
 *
 * @param {string} id
 * @returns {boolean}
 */
export function hasSpriteSymbol(id) {
  return !!spriteContainerElement().querySelector(
    `symbol[id="${CSS.escape(id)}"]`
  );
}

/**
 * Appends the `<symbol>` markup of every icon whose id is not already rendered
 * under `searchRoot`, so `<use href="#id">` resolves for it.
 *
 * @param {Element} target - Element the missing symbols are appended to.
 * @param {Array<{id: string, symbol?: string}>} icons - Icons and, for those the
 *   target cannot already render, their `<symbol>` markup.
 * @param {ParentNode} searchRoot - Scope the existing-symbol lookup runs against.
 */
function appendSymbols(target, icons, searchRoot) {
  const candidates = icons.filter(({ symbol }) => symbol);

  if (!candidates.length) {
    return;
  }

  const present = new Set(
    Array.from(searchRoot.querySelectorAll("symbol[id]"), ({ id }) => id)
  );
  const missing = candidates.filter(({ id }) => !present.has(id));

  if (missing.length) {
    target.insertAdjacentHTML(
      "beforeend",
      missing.map(({ symbol }) => symbol).join("")
    );
  }
}

/**
 * Adds symbols to the page sprite for icons it does not already have, so
 * `<use href="#id">` resolves for a value picked before it joins the sprite.
 *
 * @param {Array<{id: string, symbol?: string}>} icons - Icons and, for those the
 *   sprite cannot already render, their `<symbol>` markup.
 */
export function addExtraSpriteSymbols(icons) {
  if (!icons.some(({ symbol }) => symbol)) {
    return;
  }

  const spriteContainer = spriteContainerElement();

  let sprites = spriteContainer.querySelector(`.${EXTRA_SPRITE_NAME}`);
  if (!sprites) {
    sprites = document.createElementNS(SVG_NAMESPACE, "svg");
    sprites.classList.add(EXTRA_SPRITE_NAME);
    sprites.style.display = "none";
    spriteContainer.appendChild(sprites);
  }

  appendSymbols(sprites, icons, spriteContainer);
}

/**
 * Removes every symbol added through {@link addExtraSpriteSymbols}.
 */
export function clearExtraSpriteSymbols() {
  document
    .getElementById(SVG_CONTAINER_ID)
    ?.querySelector(`.${EXTRA_SPRITE_NAME}`)
    ?.remove();
}

/**
 * Fetches an icon's `<symbol>` markup and adds it to the page sprite when the
 * sprite cannot already render it. Failures are swallowed: the icon simply
 * stays unrendered until it joins the sprite.
 *
 * @param {string} id
 * @returns {Promise<void>}
 */
export async function ensureSpriteSymbol(id) {
  if (hasSpriteSymbol(id)) {
    return;
  }

  try {
    const symbol = await ajax(`/svg-sprite/search/${encodeURIComponent(id)}`);
    addExtraSpriteSymbols([{ id, symbol }]);
  } catch {}
}

export function loadSprites(spritePath, spriteName) {
  const spriteContainer = spriteContainerElement();

  let sprites = spriteContainer.querySelector(`.${spriteName}`);
  if (!sprites) {
    sprites = document.createElement("div");
    sprites.className = spriteName;
    spriteContainer.appendChild(sprites);
  }

  return loadScript(spritePath).then(() => {
    sprites.innerHTML = window.__svg_sprite;
    // we got to clean up here... this is one giant string
    delete window.__svg_sprite;
  });
}
