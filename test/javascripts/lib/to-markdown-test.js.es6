import toMarkdown from 'discourse/lib/to-markdown';

QUnit.module("lib:to-markdown");

QUnit.test("converts styles between normal words", assert => {
  const html = `Line with <s>styles</s> <b><i>between</i></b> words.`;
  const markdown = `Line with ~~styles~~ **_between_** words.`;
  assert.equal(toMarkdown(html), markdown);
});

QUnit.test("converts inline nested styles", assert => {
  const html = `<em>Italicised line with <strong>some random</strong> <b>bold</b> words.</em>`;
  const markdown = `_Italicised line with **some random** **bold** words._`;
  assert.equal(toMarkdown(html), markdown);
});

QUnit.test("converts a link", assert => {
  const html = `<a href="https://discourse.org">Discourse</a>`;
  const markdown = `[Discourse](https://discourse.org)`;
  assert.equal(toMarkdown(html), markdown);
});

QUnit.test("put raw URL instead of converting the link", assert => {
  let url = "https://discourse.org";
  const html = () => `<a href="${url}">${url}</a>`;

  assert.equal(toMarkdown(html()), url);

  url = "discourse.org/t/topic-slug/1";
  assert.equal(toMarkdown(html()), url);
});

QUnit.test("skip empty link", assert => {
  assert.equal(toMarkdown(`<a href="https://example.com"></a>`), "");
});

QUnit.test("converts heading tags", assert => {
  const html = `
  <h1>Heading 1</h1>
  <h2>Heading 2</h2>

  \t  <h3>Heading 3</h3>


  <h4>Heading 4</h4>



<h5>Heading 5</h5>




<h6>Heading 6</h6>
  `;
  const markdown = `# Heading 1\n\n## Heading 2\n\n### Heading 3\n\n#### Heading 4\n\n##### Heading 5\n\n###### Heading 6`;
  assert.equal(toMarkdown(html), markdown);
});
