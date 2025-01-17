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
import * as tabs from "./tabs";
import * as textPostProcess from "./text-post-process";
import * as uploadProtocol from "./upload-protocol";
import * as watchedWords from "./watched-words";

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
  feature("tabs", tabs),
];

function feature(id, { setup, priority = 0 }) {
  return { id, setup, priority };
}
