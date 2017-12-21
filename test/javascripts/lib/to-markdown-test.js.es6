import toMarkdown from 'discourse/lib/to-markdown';

QUnit.module("lib:to-markdown");

QUnit.test("converts styles between normal words", assert => {
  const html = `Line with <s>styles</s> <b><i>between</i></b> words.`;
  const markdown = `Line with ~~styles~~ **_between_** words.`;
  assert.equal(toMarkdown(html), markdown);
});

QUnit.test("converts inline nested styles", assert => {
  let html = `<em>Italicised line with <strong>some random</strong> <b>bold</b> words.</em>`;
  let markdown = `_Italicised line with **some random** **bold** words._`;
  assert.equal(toMarkdown(html), markdown);

  html = `<i class="fa">Italicised line
   with <b title="strong">some
   random</b> <s>bold</s> words.</i>`;
  markdown = `<i>Italicised line\n with <b>some\n random</b> ~~bold~~ words.</i>`;
  assert.equal(toMarkdown(html), markdown);
});

QUnit.test("converts a link", assert => {
  let html = `<a href="https://discourse.org">Discourse</a>`;
  let markdown = `[Discourse](https://discourse.org)`;
  assert.equal(toMarkdown(html), markdown);

  html = `<a href="https://discourse.org">Disc\n\n\nour\n\nse</a>`;
  markdown = `[Disc\nour\nse](https://discourse.org)`;
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

QUnit.test("converts ul list tag", assert => {
  const html = `
  <ul>
    <li>Item 1</li>
    <li>
      Item 2
      <ul>
        <li>Sub Item 1</li>
        <li>Sub Item 2</li>
        <ul><li>Sub <i>Sub</i> Item 1</li><li>Sub <b>Sub</b> Item 2</li></ul>
      </ul>
    </li>
    <li>Item 3</li>
  </ul>
  `;
  const markdown = `* Item 1\n* Item 2\n\n  * Sub Item 1\n  * Sub Item 2\n\n    * Sub _Sub_ Item 1\n    * Sub **Sub** Item 2\n\n* Item 3`;
  assert.equal(toMarkdown(html), markdown);
});

QUnit.test("stripes unwanted inline tags", assert => {
  const html = `
  <p>Lorem ipsum <span>dolor sit amet, consectetur</span> <strike>elit.</strike></p>
  <p>Ut minim veniam, <label>quis nostrud</label> laboris <nisi> ut aliquip ex ea</nisi> commodo.</p>
  `;
  const markdown = `Lorem ipsum dolor sit amet, consectetur ~~elit.~~\n\nUt minim veniam, quis nostrud laboris  ut aliquip ex ea commodo.`;
  assert.equal(toMarkdown(html), markdown);
});

QUnit.test("converts table tags", assert => {
  const html = `<address>Discourse Avenue</address><b>laboris</b>
  <table>
    <thead> <tr><th>Heading 1</th><th>Head 2</th></tr> </thead>
      <tbody>
        <tr><td>Lorem</td><td>ipsum</td></tr>
        <tr><td><b>dolor</b></td> <td><i>sit amet</i></td></tr></tbody>
</table>
  `;
  const markdown = `Discourse Avenue\n\n**laboris**\n\n|Heading 1|Head 2|\n| --- | --- |\n|Lorem|ipsum|\n|**dolor**|_sit amet_|`;
  assert.equal(toMarkdown(html), markdown);
});

QUnit.test("returns empty string if table format not supported", assert => {
  let html = `<table>
    <thead> <tr><th>Headi\n\nng 1</th><th>Head 2</th></tr> </thead>
      <tbody>
        <tr><td>Lorem</td><td>ipsum</td></tr>
        <tr><td><a href="http://example.com"><img src="http://dolor.com/image.png" /></a></td> <td><i>sit amet</i></td></tr></tbody>
</table>
  `;
  assert.equal(toMarkdown(html), "");

  html = `<table>
    <thead> <tr><th>Heading 1</th></tr> </thead>
      <tbody>
        <tr><td>Lorem</td></tr>
        <tr><td><i>sit amet</i></td></tr></tbody>
</table>
  `;
  assert.equal(toMarkdown(html), "");

  html = `<table><tr><td>Lorem</td><td><i>sit amet</i></td></tr></table>`;
  assert.equal(toMarkdown(html), "");
});

QUnit.test("converts img tag", assert => {
  const url = "https://example.com/image.png";
  let html = `<img src="${url}" width="100" height="50">`;
  assert.equal(toMarkdown(html), `![|100x50](${url})`);

  html = `<div><span><img src="${url}" alt="description" width="50" height="100" /></span></div>`;
  assert.equal(toMarkdown(html), `![description|50x100](${url})`);

  html = `<a href="http://example.com"><img src="${url}" alt="description" /></a>`;
  assert.equal(toMarkdown(html), `[![description](${url})](http://example.com)`);

  html = `<a href="http://example.com">description <img src="${url}" /></a>`;
  assert.equal(toMarkdown(html), `[description ![](${url})](http://example.com)`);

  html = `<img alt="description" />`;
  assert.equal(toMarkdown(html), "");

  html = `<a><img src="${url}" alt="description" /></a>`;
  assert.equal(toMarkdown(html), `![description](${url})`);
});

QUnit.test("supporting html tags by keeping them", assert => {
  let html = "Lorem <del>ipsum dolor</del> sit <big>amet, <ins>consectetur</ins></big>";
  let output = html;
  assert.equal(toMarkdown(html), output);

  html = `Lorem <del style="font-weight: bold">ipsum dolor</del> sit <big>amet, <ins onclick="alert('hello')">consectetur</ins></big>`;
  assert.equal(toMarkdown(html), output);

  html = `<a href="http://example.com" onload="">Lorem <del style="font-weight: bold">ipsum dolor</del> sit</a>.`;
  output = `[Lorem <del>ipsum dolor</del> sit](http://example.com).`;
  assert.equal(toMarkdown(html), output);

  html = `Lorem <del>ipsum \n\n dolor</del> sit.`;
  assert.equal(toMarkdown(html), html);

  html = `Lorem <a href="http://example.com"><del>ipsum \n\n\n dolor</del> sit.</a>`;
  output = `Lorem [<del>ipsum \n dolor</del> sit.](http://example.com)`;
  assert.equal(toMarkdown(html), output);
});

QUnit.test("converts code tags", assert => {
  let html = `Lorem ipsum dolor sit amet,
  <pre><code>var helloWorld = () => {
  alert('    hello \t\t world    ');
    return;
}
helloWorld();</code></pre>
  consectetur.`;
  let output = `Lorem ipsum dolor sit amet,\n\n\`\`\`\nvar helloWorld = () => {\n  alert('    hello \t\t world    ');\n    return;\n}\nhelloWorld();\n\`\`\`\n\nconsectetur.`;

  assert.equal(toMarkdown(html), output);

  html = `Lorem ipsum dolor sit amet, <code>var helloWorld = () => {
  alert('    hello \t\t world    ');
    return;
}
helloWorld();</code> consectetur.`;
  output = `Lorem ipsum dolor sit amet, \`var helloWorld = () => {\n  alert('    hello \t\t world    ');\n    return;\n}\nhelloWorld();\` consectetur.`;

  assert.equal(toMarkdown(html), output);
});

QUnit.test("converts blockquote tag", assert => {
  let html = "<blockquote>Lorem ipsum</blockquote>";
  let output = "> Lorem ipsum";
  assert.equal(toMarkdown(html), output);

  html = "<blockquote>Lorem ipsum</blockquote><blockquote><p>dolor sit amet</p></blockquote>";
  output = "> Lorem ipsum\n\n> dolor sit amet";
  assert.equal(toMarkdown(html), output);

  html = "<blockquote>\nLorem ipsum\n<blockquote><p>dolor <blockquote>sit</blockquote> amet</p></blockquote></blockquote>";
  output = "> Lorem ipsum\n> > dolor\n> > > sit\n> > amet";
  assert.equal(toMarkdown(html), output);
});

QUnit.test("converts ol list tag", assert => {
  const html = `Testing
  <ol>
    <li>Item 1</li>
    <li>
      Item 2
      <ol start="100">
        <li>Sub Item 1</li>
        <li>Sub Item 2</li>
        <ul><li>Sub <i>Sub</i> Item 1</li><li>Sub <b>Sub</b> Item 2</li></ul>
      </ol>
    </li>
    <li>Item 3</li>
  </ol>
  `;
  const markdown = `Testing\n\n1. Item 1\n2. Item 2\n\n  100. Sub Item 1\n  101. Sub Item 2\n\n    * Sub _Sub_ Item 1\n    * Sub **Sub** Item 2\n\n3. Item 3`;
  assert.equal(toMarkdown(html), markdown);
});
