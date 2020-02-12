import toMarkdown from "discourse/lib/to-markdown";

QUnit.module("lib:to-markdown");

QUnit.test("converts styles between normal words", assert => {
  const html = `Line with <s>styles</s> <b><i>between</i></b> words.`;
  const markdown = `Line with ~~styles~~ ***between*** words.`;
  assert.equal(toMarkdown(html), markdown);

  assert.equal(toMarkdown("A <b>bold </b>word"), "A **bold** word");
});

QUnit.test("converts inline nested styles", assert => {
  let html = `<em>Italicised line with <strong>some random</strong> <b>bold</b> words.</em>`;
  let markdown = `*Italicised line with **some random** **bold** words.*`;
  assert.equal(toMarkdown(html), markdown);

  html = `<i class="fa">Italicised line
   with <b title="strong">some<br>
   random</b> <s>bold</s> words.</i>`;
  markdown = `<i>Italicised line with <b>some\nrandom</b> ~~bold~~ words.</i>`;
  assert.equal(toMarkdown(html), markdown);
});

QUnit.test("converts a link", assert => {
  let html = `<a href="https://discourse.org">Discourse</a>`;
  let markdown = `[Discourse](https://discourse.org)`;
  assert.equal(toMarkdown(html), markdown);

  html = `<a href="https://discourse.org">Disc\n\n\nour\n\nse</a>`;
  markdown = `[Disc our se](https://discourse.org)`;
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
  let html = `
  <ul>
    <li>Item 1</li>
    <li>
      Item 2
      <ul>
        <li>Sub Item 1</li>
        <li><p>Sub Item 2</p></li>
        <li>Sub Item 3<ul><li>Sub <i>Sub</i> Item 1</li><li>Sub <b>Sub</b> Item 2</li></ul></li>
      </ul>
    </li>
    <li>Item 3</li>
  </ul>
  `;
  let markdown = `* Item 1\n* Item 2\n  * Sub Item 1\n  * Sub Item 2\n  * Sub Item 3\n    * Sub *Sub* Item 1\n    * Sub **Sub** Item 2\n* Item 3`;
  assert.equal(toMarkdown(html), markdown);

  html = `
<ul>
  <li><p><span>Bullets at level 1</span></p></li>
  <li><p><span>Bullets at level 1</span></p></li>  <ul>    <li><p><span>Bullets at level 2</span></p></li>    <li><p><span>Bullets at level 2</span></p></li>    <ul>      <li><p><span>Bullets at level 3</span></p></li>    </ul>    <li><p><span>Bullets at level 2</span></p></li>  </ul>  <li><p><span>Bullets at level 1</span></p></li></ul>  `;
  markdown = `* Bullets at level 1
* Bullets at level 1
  * Bullets at level 2
  * Bullets at level 2
    * Bullets at level 3
  * Bullets at level 2
* Bullets at level 1`;
  assert.equal(toMarkdown(html), markdown);
});

QUnit.test("stripes unwanted inline tags", assert => {
  const html = `
  <p>Lorem ipsum <span>dolor sit amet, consectetur</span> <strike>elit.</strike></p>
  <p>Ut minim veniam, <label>quis nostrud</label> laboris <nisi> ut aliquip ex ea</nisi> commodo.</p>
  `;
  const markdown = `Lorem ipsum dolor sit amet, consectetur ~~elit.~~\n\nUt minim veniam, quis nostrud laboris ut aliquip ex ea commodo.`;
  assert.equal(toMarkdown(html), markdown);
});

QUnit.test("converts table tags", assert => {
  let html = `<address>Discourse Avenue</address><b>laboris</b>
  <table>
    <thead> <tr><th>Heading 1</th><th>Head 2</th></tr> </thead>
      <tbody>
        <tr><td>Lorem</td><td>ipsum</td></tr>
        <tr><td><b>dolor</b></td> <td><i>sit amet</i></td> </tr>

        </tbody>
</table>
  `;
  let markdown = `Discourse Avenue\n\n**laboris**\n\n|Heading 1|Head 2|\n| --- | --- |\n|Lorem|ipsum|\n|**dolor**|*sit amet*|`;
  assert.equal(toMarkdown(html), markdown);

  html = `<table>
            <tr><th>Heading 1</th><th>Head 2</th></tr>
            <tr><td><a href="http://example.com"><img src="http://example.com/image.png" alt="Lorem" width="45" height="45"></a></td><td>ipsum</td></tr>
          </table>`;
  markdown = `|Heading 1|Head 2|\n| --- | --- |\n|[![Lorem\\|45x45](http://example.com/image.png)](http://example.com)|ipsum|`;
  assert.equal(toMarkdown(html), markdown);
});

QUnit.test(
  "replace pipes with spaces if table format not supported",
  assert => {
    let html = `<table>
    <thead> <tr><th>Headi<br><br>ng 1</th><th>Head 2</th></tr> </thead>
      <tbody>
        <tr><td>Lorem</td><td>ipsum</td></tr>
        <tr><td><a href="http://example.com"><img src="http://dolor.com/image.png" /></a></td> <td><i>sit amet</i></td></tr></tbody>
</table>
  `;
    let markdown = `Headi\n\nng 1 Head 2\nLorem ipsum\n[![](http://dolor.com/image.png)](http://example.com) *sit amet*`;
    assert.equal(toMarkdown(html), markdown);

    html = `<table>
    <thead> <tr><th>Heading 1</th></tr> </thead>
      <tbody>
        <tr><td>Lorem</td></tr>
        <tr><td><i>sit amet</i></td></tr></tbody>
</table>
  `;
    markdown = `Heading 1\nLorem\n*sit amet*`;
    assert.equal(toMarkdown(html), markdown);

    html = `<table><tr><td>Lorem</td><td><strong>sit amet</strong></td></tr></table>`;
    markdown = `Lorem **sit amet**`;
    assert.equal(toMarkdown(html), markdown);
  }
);

QUnit.test("converts img tag", assert => {
  const url = "https://example.com/image.png";
  const base62SHA1 = "q16M6GR110R47Z9p9Dk3PMXOJoE";
  let html = `<img src="${url}" width="100" height="50">`;
  assert.equal(toMarkdown(html), `![|100x50](${url})`);

  html = `<img src="${url}" width="100" height="50" title="some title">`;
  assert.equal(toMarkdown(html), `![|100x50](${url} "some title")`);

  html = `<img src="${url}" width="100" height="50" title="some title" data-base62-sha1="${base62SHA1}">`;
  assert.equal(
    toMarkdown(html),
    `![|100x50](upload://${base62SHA1} "some title")`
  );

  html = `<div><span><img src="${url}" alt="description" width="50" height="100" /></span></div>`;
  assert.equal(toMarkdown(html), `![description|50x100](${url})`);

  html = `<a href="http://example.com"><img src="${url}" alt="description" /></a>`;
  assert.equal(
    toMarkdown(html),
    `[![description](${url})](http://example.com)`
  );

  html = `<a href="http://example.com">description <img src="${url}" /></a>`;
  assert.equal(
    toMarkdown(html),
    `[description ![](${url})](http://example.com)`
  );

  html = `<img alt="description" />`;
  assert.equal(toMarkdown(html), "");

  html = `<a><img src="${url}" alt="description" /></a>`;
  assert.equal(toMarkdown(html), `![description](${url})`);
});

QUnit.test("supporting html tags by keeping them", assert => {
  let html =
    "Lorem <del>ipsum dolor</del> sit <big>amet, <ins>consectetur</ins></big>";
  let output = html;
  assert.equal(toMarkdown(html), output);

  html = `Lorem <del style="font-weight: bold">ipsum dolor</del> sit <big>amet, <ins onclick="alert('hello')">consectetur</ins></big>`;
  assert.equal(toMarkdown(html), output);

  html = `<a href="http://example.com" onload="">Lorem <del style="font-weight: bold">ipsum dolor</del> sit</a>.`;
  output = `[Lorem <del>ipsum dolor</del> sit](http://example.com).`;
  assert.equal(toMarkdown(html), output);

  html = `Lorem <del>ipsum dolor</del> sit.`;
  assert.equal(toMarkdown(html), html);

  html = `Have you tried clicking the <kbd>Help Me!</kbd> button?`;
  assert.equal(toMarkdown(html), html);

  html = `Lorem <a href="http://example.com"><del>ipsum \n\n\n dolor</del> sit.</a>`;
  output = `Lorem [<del>ipsum dolor</del> sit.](http://example.com)`;
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
helloWorld();</code>consectetur.`;
  output = `Lorem ipsum dolor sit amet, \`var helloWorld = () => {\n  alert('    hello \t\t world    ');\n    return;\n}\nhelloWorld();\` consectetur.`;

  assert.equal(toMarkdown(html), output);
});

QUnit.test("converts blockquote tag", assert => {
  let html = "<blockquote>Lorem ipsum</blockquote>";
  let output = "> Lorem ipsum";
  assert.equal(toMarkdown(html), output);

  html =
    "<blockquote>Lorem ipsum</blockquote><blockquote><p>dolor sit amet</p></blockquote>";
  output = "> Lorem ipsum\n\n> dolor sit amet";
  assert.equal(toMarkdown(html), output);

  html =
    "<blockquote>\nLorem ipsum\n<blockquote><p>dolor <blockquote>sit</blockquote> amet</p></blockquote></blockquote>";
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
      </ol>
    </li>
    <li>Item 3</li>
  </ol>
  `;
  const markdown = `Testing\n\n1. Item 1\n2. Item 2\n  100. Sub Item 1\n  101. Sub Item 2\n3. Item 3`;
  assert.equal(toMarkdown(html), markdown);
});

QUnit.test("converts list tag from word", assert => {
  const html = `Sample<!--StartFragment-->
  <p class=MsoListParagraphCxSpFirst style='text-indent:-.25in;mso-list:l0 level1 lfo1'>
    <![if !supportLists]>
    <span style='font-family:Symbol;mso-fareast-font-family:Symbol;mso-bidi-font-family:  Symbol;mso-bidi-font-weight:bold'>
      <span style='mso-list:Ignore'>·
        <span style='font:7.0pt "Times New Roman"'> </span>
      </span>
    </span>
    <![endif]>
    <b>Item 1
      <o:p></o:p>
    </b>
  </p>
  <p class=MsoListParagraphCxSpMiddle style='text-indent:-.25in;mso-list:l0 level2 lfo1'>
    <![if !supportLists]>
    <span style='font-family:Symbol;mso-fareast-font-family:Symbol;mso-bidi-font-family:  Symbol;mso-bidi-font-style:italic'>
      <span style='mso-list:Ignore'>·
        <span style='font:7.0pt "Times New Roman"'> </span>
      </span>
    </span>
    <![endif]>
    <i>Item 2
      <o:p></o:p>
    </i>
  </p>
  <p class=MsoListParagraphCxSpMiddle style='text-indent:-.25in;mso-list:l0 level3 lfo1'>
    <![if !supportLists]>
    <span style='font-family:Symbol;mso-fareast-font-family:Symbol;mso-bidi-font-family:  Symbol'>
      <span style='mso-list:Ignore'>·
        <span style='font:7.0pt "Times New Roman"'> </span>
      </span>
    </span>
    <![endif]>Item 3 </p>
  <p class=MsoListParagraphCxSpLast style='text-indent:-.25in;mso-list:l0 level1 lfo1'>
    <![if !supportLists]>
    <span style='font-family:Symbol;mso-fareast-font-family:Symbol;mso-bidi-font-family:  Symbol'>
      <span style='mso-list:Ignore'>·
        <span style='font:7.0pt "Times New Roman"'> </span>
      </span>
    </span>
    <![endif]>Item 4</p>
  <!--EndFragment-->List`;
  const markdown = `Sample\n\n* **Item 1**\n  * *Item 2*\n    * Item 3\n* Item 4\n\nList`;
  assert.equal(toMarkdown(html), markdown);
});

QUnit.test("keeps mention/hash class", assert => {
  const html = `
    <p>User mention: <a class="mention" href="/u/discourse">@discourse</a></p>
    <p>Group mention: <a class="mention-group" href="/groups/discourse">@discourse-group</a></p>
    <p>Category link: <a class="hashtag" href="/c/foo/1">#<span>foo</span></a></p>
    <p>Sub-category link: <a class="hashtag" href="/c/foo/bar/2">#<span>foo:bar</span></a></p>
  `;

  const markdown = `User mention: @discourse\n\nGroup mention: @discourse-group\n\nCategory link: #foo\n\nSub-category link: #foo:bar`;

  assert.equal(toMarkdown(html), markdown);
});

QUnit.test("keeps emoji and removes click count", assert => {
  const html = `
    <p>
      A <a href="http://example.com">link</a><span class="badge badge-notification clicks" title="1 click">1</span> with click count
      and <img class="emoji" title=":boom:" src="https://d11a6trkgmumsb.cloudfront.net/images/emoji/twitter/boom.png?v=5" alt=":boom:" /> emoji.
    </p>
  `;

  const markdown = `A [link](http://example.com) with click count and :boom: emoji.`;

  assert.equal(toMarkdown(html), markdown);
});

QUnit.test("keeps emoji syntax for custom emoji", assert => {
  const html = `
    <p>
      <img class="emoji emoji-custom" title=":custom_emoji:" src="https://d11a6trkgmumsb.cloudfront.net/images/emoji/custom_emoji" alt=":custom_emoji:" />
    </p>
  `;

  const markdown = `:custom_emoji:`;

  assert.equal(toMarkdown(html), markdown);
});

QUnit.test("converts image lightboxes to markdown", assert => {
  let html = `
  <a class="lightbox" href="https://d11a6trkgmumsb.cloudfront.net/uploads/default/original/1X/8hkjhk7692f6afed3cb99d43ab2abd4e30aa8cba.jpeg" data-download-href="https://d11a6trkgmumsb.cloudfront.net/uploads/default/8hkjhk7692f6afed3cb99d43ab2abd4e30aa8cba" title="sherlock3_sig.jpg" rel="nofollow noopener"><img src="https://d11a6trkgmumsb.cloudfront.net/uploads/default/optimized/1X/8hkjhk7692f6afed3cb99d43ab2abd4e30aa8cba_2_689x459.jpeg" alt="sherlock3_sig" width="689" height="459" class="d-lazyload" srcset="https://d11a6trkgmumsb.cloudfront.net/uploads/default/optimized/1X/8hkjhk7692f6afed3cb99d43ab2abd4e30aa8cba_2_689x459.jpeg, https://d11a6trkgmumsb.cloudfront.net/uploads/default/optimized/1X/8hkjhk7692f6afed3cb99d43ab2abd4e30aa8cba_2_1033x688.jpeg 1.5x, https://d11a6trkgmumsb.cloudfront.net/uploads/default/optimized/1X/8hkjhk7692f6afed3cb99d43ab2abd4e30aa8cba_2_1378x918.jpeg 2x"><div class="meta">
  <span class="filename">sherlock3_sig.jpg</span><span class="informations">5496×3664 2 MB</span><span class="expand"></span>
  </div></a>
  `;
  let markdown = `![sherlock3_sig.jpg](https://d11a6trkgmumsb.cloudfront.net/uploads/default/original/1X/8hkjhk7692f6afed3cb99d43ab2abd4e30aa8cba.jpeg)`;

  assert.equal(toMarkdown(html), markdown);

  html = `<a class="lightbox" href="https://d11a6trkgmumsb.cloudfront.net/uploads/default/original/1X/8hkjhk7692f6afed3cb99d43ab2abd4e30aa8cba.jpeg" data-download-href="https://d11a6trkgmumsb.cloudfront.net/uploads/default/8hkjhk7692f6afed3cb99d43ab2abd4e30aa8cba" title="sherlock3_sig.jpg" rel="nofollow noopener"><img src="https://d11a6trkgmumsb.cloudfront.net/uploads/default/optimized/1X/8hkjhk7692f6afed3cb99d43ab2abd4e30aa8cba_2_689x459.jpeg" alt="sherlock3_sig" width="689" height="459" class="d-lazyload" srcset="https://d11a6trkgmumsb.cloudfront.net/uploads/default/optimized/1X/8hkjhk7692f6afed3cb99d43ab2abd4e30aa8cba_2_689x459.jpeg, https://d11a6trkgmumsb.cloudfront.net/uploads/default/optimized/1X/8hkjhk7692f6afed3cb99d43ab2abd4e30aa8cba_2_1033x688.jpeg 1.5x, https://d11a6trkgmumsb.cloudfront.net/uploads/default/optimized/1X/8hkjhk7692f6afed3cb99d43ab2abd4e30aa8cba_2_1378x918.jpeg 2x"></a>`;

  assert.equal(toMarkdown(html), markdown);

  html = `
  <a class="lightbox" href="https://d11a6trkgmumsb.cloudfront.net/uploads/default/original/1X/8hkjhk7692f6afed3cb99d43ab2abd4e30aa8cba.jpeg" data-download-href="https://d11a6trkgmumsb.cloudfront.net/uploads/default/8hkjhk7692f6afed3cb99d43ab2abd4e30aa8cba" title="sherlock3_sig.jpg" rel="nofollow noopener"><img src="https://d11a6trkgmumsb.cloudfront.net/uploads/default/optimized/1X/8hkjhk7692f6afed3cb99d43ab2abd4e30aa8cba_2_689x459.jpeg" data-base62-sha1="1frsimI7TOtFJyD2LLyKSHM8JWe" alt="sherlock3_sig" width="689" height="459" class="d-lazyload" srcset="https://d11a6trkgmumsb.cloudfront.net/uploads/default/optimized/1X/8hkjhk7692f6afed3cb99d43ab2abd4e30aa8cba_2_689x459.jpeg, https://d11a6trkgmumsb.cloudfront.net/uploads/default/optimized/1X/8hkjhk7692f6afed3cb99d43ab2abd4e30aa8cba_2_1033x688.jpeg 1.5x, https://d11a6trkgmumsb.cloudfront.net/uploads/default/optimized/1X/8hkjhk7692f6afed3cb99d43ab2abd4e30aa8cba_2_1378x918.jpeg 2x"><div class="meta">
  <span class="filename">sherlock3_sig.jpg</span><span class="informations">5496×3664 2 MB</span><span class="expand"></span>
  </div></a>
  `;
  markdown = `![sherlock3_sig.jpg](upload://1frsimI7TOtFJyD2LLyKSHM8JWe)`;

  assert.equal(toMarkdown(html), markdown);
});

QUnit.test("converts quotes to markdown", assert => {
  let html = `
  <p>there is a quote below</p>
  <aside class="quote no-group" data-username="foo" data-post="1" data-topic="2">
  <div class="title" style="cursor: pointer;">
  <div class="quote-controls"><span class="svg-icon-title" title="expand/collapse"><svg class="fa d-icon d-icon-chevron-down svg-icon svg-string" xmlns="http://www.w3.org/2000/svg"><use xlink:href="#chevron-down"></use></svg></span><a href="/t/hello-world-i-am-posting-an-image/158/1" title="go to the quoted post" class="back"><svg class="fa d-icon d-icon-arrow-up svg-icon svg-string" xmlns="http://www.w3.org/2000/svg"><use xlink:href="#arrow-up"></use></svg></a></div>
  <img alt="" width="20" height="20" src="" class="avatar"> foo:</div>
  <blockquote>
  <p>this is a quote</p>
  </blockquote>
  </aside>
  <p>there is a quote above</p>
  `;

  let markdown = `
there is a quote below

[quote="foo, post:1, topic:2"]
this is a quote
[/quote]

there is a quote above
`;

  assert.equal(toMarkdown(html), markdown.trim());
});
