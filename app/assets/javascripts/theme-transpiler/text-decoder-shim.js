import { TextDecoder, TextEncoder } from "fastestsmallesttextencoderdecoder";

export default function patch() {
  globalThis.TextEncoder = TextEncoder;
  globalThis.TextDecoder = TextDecoder;
}
