import { default as PrettyText, buildOptions } from 'pretty-text/pretty-text';

module("lib:details-cooked-test");

const defaultOpts = buildOptions({
  siteSettings: {
    enable_emoji: true,
    emoji_set: 'emoji_one',
    highlighted_languages: 'json|ruby|javascript',
    default_code_lang: 'auto',
    censored_words: 'shucks|whiz|whizzer'
  },
  getURL: url => url
});

function cooked(input, expected, text) {
  equal(new PrettyText(defaultOpts).cook(input), expected.replace(/\/>/g, ">"), text);
};

test("details", () => {
  cooked(`<details><summary>Info</summary>coucou</details>`,
         `<details><summary>Info</summary>\n\n<p>coucou</p>\n\n</details>`,
         "manual HTML for details");
  cooked(` <details><summary>Info</summary>coucou</details>`,
         `<details><summary>Info</summary>\n\n<p>coucou</p>\n\n</details>`,
         "manual HTML for details with a space");

  cooked(`<details open="open"><summary>Info</summary>coucou</details>`,
         `<details open="open"><summary>Info</summary>\n\n<p>coucou</p>\n\n</details>`,
         "open attribute");

  cooked(`<details open><summary>Info</summary>coucou</details>`,
         `<details open><summary>Info</summary>\n\n<p>coucou</p>\n\n</details>`,
         "open attribute");
});
