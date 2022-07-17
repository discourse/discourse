export default {
  "/admin/customize/watched_words.json": {
    actions: ["block", "censor", "require_approval", "flag", "replace", "tag"],
    words: [
      { id: 1, word: "liquorice", action: "block" },
      { id: 2, word: "anise", action: "block" },
      { id: 3, word: "pyramid", action: "flag" },
      { id: 4, word: "scheme", action: "flag" },
      { id: 5, word: "coupon", action: "require_approval" },
      { id: 6, word: '<img src="x">', action: "block" },
      {
        id: 7,
        word: "hi",
        regexp: "(hi)",
        replacement: "hello",
        action: "replace",
      },
      {
        id: 8,
        word: "hello",
        regexp: "(hello)",
        replacement: "greeting",
        action: "tag",
      },
    ],
    compiled_regular_expressions: {
      block: [
        { '(?:\\W|^)(liquorice|anise|<img\\ src="x">)(?=\\W|$)': { case_sensitive: false }, },
      ],
      censor: [],
      require_approval: [
        { "(?:\\W|^)(coupon)(?=\\W|$)": { case_sensitive: false }, },
      ],
      flag: [{ "(?:\\W|^)(pyramid|scheme)(?=\\W|$)": {case_sensitive: false }, },],
      replace: [{ "(?:\\W|^)(hi)(?=\\W|$)": { case_sensitive: false }},],
      tag: [{ "(?:\\W|^)(hello)(?=\\W|$)": { case_sensitive: false }, },],
    },
  },
};
