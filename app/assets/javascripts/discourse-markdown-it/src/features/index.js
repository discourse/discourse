import * as anchor from "./anchor";
import * as bbcodeBlock from "./bbcode-block";
import * as bbcodeInline from "./bbcode-inline";
import * as censored from "./censored";
import * as code from "./code";
import * as customTypographerReplacements from "./custom-typographer-replacements";
import * as dWrap from "./d-wrap";
import * as emoji from "./emoji";
import * as hashtagAutocomplete from "./hashtag-autocomplete";
import * as htmlImg from "./html-img";
import * as imageControls from "./image-controls";
import * as imageGrid from "./image-grid";
import * as mentions from "./mentions";
import * as newline from "./newline";
import * as onebox from "./onebox";
import * as paragraph from "./paragraph";
import * as quotes from "./quotes";
import * as table from "./table";
import * as textPostProcess from "./text-post-process";
import * as uploadProtocol from "./upload-protocol";
import * as watchedWords from "./watched-words";

export default [
  feature("anchor", anchor),
  feature("bbcode-block", bbcodeBlock),
  feature("bbcode-inline", bbcodeInline),
  feature("censored", censored),
  feature("code", code),
  feature("custom-typographer-replacements", customTypographerReplacements),
  feature("d-wrap", dWrap),
  feature("emoji", emoji),
  feature("hashtag-autocomplete", hashtagAutocomplete),
  feature("html-img", htmlImg),
  feature("image-controls", imageControls),
  feature("image-grid", imageGrid),
  feature("mentions", mentions),
  feature("newline", newline),
  feature("onebox", onebox),
  feature("paragraph", paragraph),
  feature("quotes", quotes),
  feature("table", table),
  feature("text-post-process", textPostProcess),
  feature("upload-protocol", uploadProtocol),
  feature("watched-words", watchedWords),
];

function feature(id, { setup, priority = 0 }) {
  return { id, setup, priority };
}
