export default {
  "/admin/customize/watched_words.json": {
    actions: ["block", "censor", "require_approval", "flag", "replace", "tag"],
    words: [
      { id: 1, word: "liquorice", action: "block", case_sensitive: false },
      { id: 2, word: "anise", action: "block", case_sensitive: false },
      { id: 3, word: "pyramid", action: "flag", case_sensitive: false },
      { id: 4, word: "scheme", action: "flag", case_sensitive: false },
      { id: 5, word: "coupon", action: "require_approval", case_sensitive: false },
      { id: 6, word: '<img src="x">', action: "block", case_sensitive: false },
      {
        id: 7,
        word: "hi",
        regexp: "(hi)",
        replacement: "hello",
        action: "replace",
        case_sensitive: false,
      },
      {
        id: 8,
        word: "hello",
        regexp: "(hello)",
        replacement: "greeting",
        action: "tag",
        case_sensitive: false,
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
