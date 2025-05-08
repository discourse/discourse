import { TextDecoder, TextEncoder } from "fastestsmallesttextencoderdecoder";

export default function patch() {
  globalThis.TextEncoder = TextEncoder;
  globalThis.TextDecoder = TextDecoder;
}

import path from "path";

path.win32 = {
  sep: "/",
};
