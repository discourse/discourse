import I18n from "I18n";

function imageGridRule(state) {
  const tokens = state.tokens;
  const CHILD_TYPES = ["image", "softbreak"];

  const disabled = tokens.some((t) =>
    t.content.startsWith('<div data-disable-image-grid="true">')
  );

  for (let i = 1; i < tokens.length - 1; i++) {
    const token = tokens[i];

    if (token.type !== "inline") {
      continue;
    }

    if (
      !token.children.reduce(
        (acc, t) => acc && CHILD_TYPES.includes(t.type),
        true
      )
    ) {
      continue;
    }
    token.children = token.children.filter((tk) => {
      return tk.type === "image";
    });

    // TODO: should this be configurable?
    if (token.children.length < 5) {
      continue;
    }

    tokens[i - 1].type = "image_grid_open";
    tokens[i - 1].tag = "div";
    tokens[i - 1].attrSet("class", "auto-image-grid");
    tokens[i - 1].attrSet("data-auto-image-grid", disabled ? "off" : "on");

    tokens[i + 1].type = "image_grid_close";
    tokens[i + 1].tag = "div";
  }
}

function buildImageToggleButtons(tokens) {
  const gridOpenToken = tokens.find((tk) => {
    return tk.type === "image_grid_open";
  });

  const labelToggle = gridOpenToken?.attrGet("data-auto-image-grid") === "off";

  return `
  <div class="image-grid-toggle">
    <svg class="fa d-icon d-icon-th svg-icon svg-string" xmlns="http://www.w3.org/2000/svg">
      <use href="#th"></use>
    </svg>
    ${I18n.t(
      labelToggle ? "composer.enable_image_grid" : "composer.disable_image_grid"
    )}
  </div>
  `;
}

export function setup(helper) {
  helper.registerOptions((opts, siteSettings) => {
    opts.enableImageGrid = !!siteSettings.experimental_post_image_grid;
  });

  helper.allowList(["div.auto-image-grid"]);

  const opts = helper.getOptions();
  if (opts.previewing) {
    helper.allowList([
      "div.image-grid-toggle",
      "svg[class=fa d-icon d-icon-th svg-icon svg-string]",
      "use[href=#th]",
      "span.enable",
      "span.disable",
    ]);
  }

  helper.registerPlugin((md) => {
    if (!md.options.discourse.enableImageGrid) {
      return;
    }

    md.core.ruler.after("inline", "image_grid", imageGridRule);

    const proxy = (tokens, idx, options, env, self) =>
      self.renderToken(tokens, idx, options);
    const gridRenderer = md.renderer.rules.image_grid_open || proxy;

    md.renderer.rules.image_grid_open = function (
      tokens,
      idx,
      options,
      env,
      self
    ) {
      if (options.discourse.previewing) {
        return `${buildImageToggleButtons(tokens)} ${gridRenderer(
          tokens,
          idx,
          options,
          env,
          self
        )}`;
      } else {
        return gridRenderer(tokens, idx, options, env, self);
      }
    };
  });
}
