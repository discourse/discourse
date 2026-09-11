import * as anchor from "./anchor.js";
import * as bbcodeBlock from "./bbcode-block.js";
import * as bbcodeInline from "./bbcode-inline.js";
import * as censored from "./censored.js";
import * as code from "./code.js";
import * as customTypographerReplacements from "./custom-typographer-replacements.js";
import * as dWrap from "./d-wrap.js";
import * as emoji from "./emoji.js";
import * as hashtagAutocomplete from "./hashtag-autocomplete.js";
import * as htmlImg from "./html-img.js";
import * as imageControls from "./image-controls.js";
import * as imageGrid from "./image-grid.js";
import * as mentions from "./mentions.js";
import * as newline from "./newline.js";
import * as onebox from "./onebox.js";
import * as paragraph from "./paragraph.js";
import * as quotes from "./quotes.js";
import * as table from "./table.js";
import * as textPostProcess from "./text-post-process.js";
import * as uploadProtocol from "./upload-protocol.js";
import * as watchedWords from "./watched-words.js";

export default [
  feature("watched-words", watchedWords),
  feature("upload-protocol", uploadProtocol),
  feature("text-post-process", textPostProcess),
  feature("table", table),
  feature("quotes", quotes),
  feature("paragraph", paragraph),
  feature("onebox", onebox),
  feature("newline", newline),
  feature("mentions", mentions),
  feature("image-grid", imageGrid),
  feature("image-controls", imageControls),
  feature("html-img", htmlImg),
  feature("hashtag-autocomplete", hashtagAutocomplete),
  feature("emoji", emoji),
  feature("d-wrap", dWrap),
  feature("custom-typographer-replacements", customTypographerReplacements),
  feature("code", code),
  feature("censored", censored),
  feature("bbcode-inline", bbcodeInline),
  feature("bbcode-block", bbcodeBlock),
  feature("anchor", anchor),
];

function feature(id, { setup, priority = 0 }) {
  return { id, setup, priority };
}
