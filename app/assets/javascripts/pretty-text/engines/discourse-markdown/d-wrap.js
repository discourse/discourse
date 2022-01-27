import { parseBBCodeTag } from "pretty-text/engines/discourse-markdown/bbcode-block";

const WRAP_CLASS = "d-wrap";

function parseAttributes(tagInfo) {
  const wrap = "wrap";

  if (tagInfo.tag === wrap) {
    const attributes = tagInfo.attrs._default || tagInfo.attrs;
    return (
      parseBBCodeTag(
        `[${wrap} ${wrap}=${attributes}]`,
        0,
        attributes.length + wrap.length * 2 + 4
      ).attrs || {}
    );
  } else {
    const attributes = tagInfo.attrs;
    attributes[wrap] = tagInfo.tag;
    return attributes;
  }
}

function camelCaseToDash(str) {
  return str.replace(/([a-zA-Z])(?=[A-Z])/g, "$1-").toLowerCase();
}

function applyDataAttributes(token, state, attributes) {
  Object.keys(attributes).forEach((tag) => {
    const value = state.md.utils.escapeHtml(attributes[tag]);
    tag = camelCaseToDash(
      state.md.utils.escapeHtml(tag.replace(/[^A-Za-z\-0-9]/g, ""))
    );

    if (value && tag?.length) {
      token.attrs.push([`data-${tag}`, value]);
    }
  });
}

function blockRule(tag) {
  return {
    tag,

    before(state, tagInfo) {
      let token = state.push("wrap_open", "div", 1);
      token.attrs = [["class", WRAP_CLASS]];

      applyDataAttributes(token, state, parseAttributes(tagInfo));
    },

    after(state) {
      state.push("wrap_close", "div", -1);
    },
  };
}

function inlineRule(tag) {
  return {
    tag,

    replace(state, tagInfo, content) {
      let token = state.push("wrap_open", "span", 1);
      token.attrs = [["class", WRAP_CLASS]];

      applyDataAttributes(token, state, parseAttributes(tagInfo));

      if (content) {
        token = state.push("text", "", 0);
        token.content = content;
      }

      state.push("wrap_close", "span", -1);
      return true;
    },
  };
}

export function setup(helper) {
  helper.registerOptions((opts, siteSettings) => {
    opts.features.customWrapTags = [
      ...new Set(
        siteSettings.custom_wrap_tags.split("|").filter(Boolean).concat("wrap")
      ),
    ];
  });

  helper.registerPlugin((md) => {
    const tags = md.options.discourse.features.customWrapTags;
    tags.forEach((tag) => {
      md.inline.bbcode.ruler.push("inline-wrap", inlineRule(tag));
      md.block.bbcode.ruler.push("block-wrap", blockRule(tag));
    });
  });

  helper.allowList([`div.${WRAP_CLASS}`, `span.${WRAP_CLASS}`, "span[data-*]"]);
}
