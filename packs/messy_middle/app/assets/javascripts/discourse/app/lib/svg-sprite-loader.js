import loadScript from "discourse/lib/load-script";

const SVG_CONTAINER_ID = "svg-sprites";

export function loadSprites(spritePath, spriteName) {
  let spriteContainer = document.getElementById(SVG_CONTAINER_ID);
  if (!spriteContainer) {
    spriteContainer = document.createElement("div");
    spriteContainer.id = SVG_CONTAINER_ID;
    const spriteWrapper = document.querySelector("discourse-assets-icons");
    spriteWrapper?.appendChild(spriteContainer);
  }

  let sprites = spriteContainer.querySelector(`.${spriteName}`);
  if (!sprites) {
    sprites = document.createElement("div");
    sprites.className = spriteName;
    spriteContainer.appendChild(sprites);
  }

  loadScript(spritePath).then(() => {
    sprites.innerHTML = window.__svg_sprite;
    // we got to clean up here... this is one giant string
    delete window.__svg_sprite;
  });
}
