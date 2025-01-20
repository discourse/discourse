import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import toMarkdown, {
  addBlockDecorateCallback,
  addTagDecorateCallback,
} from "discourse/lib/to-markdown";

module("Unit | Utility | to-markdown", function (hooks) {
  setupTest(hooks);

  test("converts styles between normal words", function (assert) {
    const html = `Line with <s>styles</s> <b><i>between</i></b> words.`;
    const markdown = `Line with ~~styles~~ ***between*** words.`;
    assert.strictEqual(toMarkdown(html), markdown);

    assert.strictEqual(toMarkdown("A <b>bold </b>word"), "A **bold** word");
    assert.strictEqual(toMarkdown("A <b>bold</b>, word"), "A **bold**, word");
  });

  test("converts inline nested styles", function (assert) {
    let html = `<em>Italicised line with <strong>some random</strong> <b>bold</b> words.</em>`;
    let markdown = `*Italicised line with **some random** **bold** words.*`;
    assert.strictEqual(toMarkdown(html), markdown);

    html = `<i class="fa">Italicised line
     with <b title="strong">some<br>
     random</b> <s>bold</s> words.</i>`;
    markdown = `<i>Italicised line with <b>some\nrandom</b> ~~bold~~ words.</i>`;
    assert.strictEqual(toMarkdown(html), markdown);

    // eslint-disable-next-line no-irregular-whitespace
    html = `<span>this is<span> </span></span><strong>bold</strong><span><span> </span>statement</span>`;
    markdown = `this is **bold** statement`;
    assert.strictEqual(toMarkdown(html), markdown);
  });

  test("converts a link", function (assert) {
    let html = `<a href="https://discourse.org">Discourse</a>`;
    let markdown = `[Discourse](https://discourse.org)`;
    assert.strictEqual(toMarkdown(html), markdown);

    html = `<a href="https://discourse.org">Disc\n\n\nour\n\nse</a>`;
    markdown = `[Disc our se](https://discourse.org)`;
    assert.strictEqual(toMarkdown(html), markdown);
  });

  test("converts a link which is an attachment", function (assert) {
    let html = `<a class="attachment" href="https://discourse.org/pdfs/stuff.pdf">stuff.pdf</a>`;
    let markdown = `[stuff.pdf|attachment](https://discourse.org/pdfs/stuff.pdf)`;
    assert.strictEqual(toMarkdown(html), markdown);
  });

  test("put raw URL instead of converting the link", function (assert) {
    let url = "https://discourse.org";
    const html = () => `<a href="${url}">${url}</a>`;

    assert.strictEqual(toMarkdown(html()), url);

    url = "discourse.org/t/topic-slug/1";
    assert.strictEqual(toMarkdown(html()), url);
  });

  test("skip empty link", function (assert) {
    assert.strictEqual(toMarkdown(`<a href="https://example.com"></a>`), "");
  });

  test("converts heading tags", function (assert) {
    const html = `
    <h1>Heading 1</h1>
    <h2>Heading 2</h2>

    \t  <h3>Heading 3</h3>


    <h4>Heading 4</h4>



  <h5>Heading 5</h5>




  <h6>Heading 6</h6>
    `;
    const markdown = `# Heading 1\n\n## Heading 2\n\n### Heading 3\n\n#### Heading 4\n\n##### Heading 5\n\n###### Heading 6`;
    assert.strictEqual(toMarkdown(html), markdown);
  });

  test("converts ul list tag", function (assert) {
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
    assert.strictEqual(toMarkdown(html), markdown);

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
    assert.strictEqual(toMarkdown(html), markdown);
  });

  test("stripes unwanted inline tags", function (assert) {
    const html = `
    <p>Lorem ipsum <span>dolor sit amet, consectetur</span> <strike>elit.</strike></p>
    <p>Ut minim veniam, <label>quis nostrud</label> laboris <nisi> ut aliquip ex ea</nisi> commodo.</p>
    `;
    const markdown = `Lorem ipsum dolor sit amet, consectetur ~~elit.~~\n\nUt minim veniam, quis nostrud laboris ut aliquip ex ea commodo.`;
    assert.strictEqual(toMarkdown(html), markdown);
  });

  test("converts table tags", function (assert) {
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
    assert.strictEqual(toMarkdown(html), markdown);

    html = `<table>
              <tr><th>Heading 1</th><th>Head 2</th></tr>
              <tr><td><a href="http://example.com"><img src="http://example.com/image.png" alt="Lorem" width="45" height="45"></a></td><td>ipsum</td></tr>
            </table>`;
    markdown = `|Heading 1|Head 2|\n| --- | --- |\n|[![Lorem\\|45x45](http://example.com/image.png)](http://example.com)|ipsum|`;
    assert.strictEqual(toMarkdown(html), markdown);
  });

  test("replace pipes with spaces if table format not supported", function (assert) {
    let html = `<table>
      <thead> <tr><th>Headi<br><br>ng 1</th><th>Head 2</th></tr> </thead>
        <tbody>
          <tr><td>Lorem</td><td>ipsum</td></tr>
          <tr><td><a href="http://example.com"><img src="http://dolor.com/image.png" /></a></td> <td><i>sit amet</i></td></tr></tbody>
  </table>
    `;
    let markdown = `Headi\n\nng 1 Head 2\nLorem ipsum\n[![](http://dolor.com/image.png)](http://example.com) *sit amet*`;
    assert.strictEqual(toMarkdown(html), markdown);

    html = `<table>
      <thead> <tr><th>Heading 1</th></tr> </thead>
        <tbody>
          <tr><td>Lorem</td></tr>
          <tr><td><i>sit amet</i></td></tr></tbody>
  </table>
    `;
    markdown = `Heading 1\nLorem\n*sit amet*`;
    assert.strictEqual(toMarkdown(html), markdown);

    html = `<table><tr><td>Lorem</td><td><strong>sit amet</strong></td></tr></table>`;
    markdown = `Lorem **sit amet**`;
    assert.strictEqual(toMarkdown(html), markdown);
  });

  test("converts img tag", function (assert) {
    const url = "https://example.com/image.png";
    const base62SHA1 = "q16M6GR110R47Z9p9Dk3PMXOJoE";
    let html = `<img src="${url}" width="100" height="50">`;
    assert.strictEqual(toMarkdown(html), `![|100x50](${url})`);

    html = `<img src="${url}" width="100" height="50" title="some title">`;
    assert.strictEqual(toMarkdown(html), `![|100x50](${url} "some title")`);

    html = `<img src="${url}" width="100" height="50" title="some title" data-base62-sha1="${base62SHA1}">`;
    assert.strictEqual(
      toMarkdown(html),
      `![|100x50](upload://${base62SHA1} "some title")`
    );

    html = `<div><span><img src="${url}" alt="description" width="50" height="100" /></span></div>`;
    assert.strictEqual(toMarkdown(html), `![description|50x100](${url})`);

    html = `<a href="http://example.com"><img src="${url}" alt="description" /></a>`;
    assert.strictEqual(
      toMarkdown(html),
      `[![description](${url})](http://example.com)`
    );

    html = `<a href="http://example.com">description <img src="${url}" /></a>`;
    assert.strictEqual(
      toMarkdown(html),
      `[description ![](${url})](http://example.com)`
    );

    html = `<img alt="description" />`;
    assert.strictEqual(toMarkdown(html), "");

    html = `<a><img src="${url}" alt="description" /></a>`;
    assert.strictEqual(toMarkdown(html), `![description](${url})`);
  });

  test("supporting html tags by keeping them", function (assert) {
    let html =
      "Lorem <del>ipsum dolor</del> sit <big>amet, <ins>consectetur</ins></big>";
    let output = html;
    assert.strictEqual(toMarkdown(html), output);

    html = `Lorem <del style="font-weight: bold">ipsum dolor</del> sit <big>amet, <ins onclick="alert('hello')">consectetur</ins></big>`;
    assert.strictEqual(toMarkdown(html), output);

    html = `<a href="http://example.com" onload="">Lorem <del style="font-weight: bold">ipsum dolor</del> sit</a>.`;
    output = `[Lorem <del>ipsum dolor</del> sit](http://example.com).`;
    assert.strictEqual(toMarkdown(html), output);

    html = `Lorem <del>ipsum dolor</del> sit.`;
    assert.strictEqual(toMarkdown(html), html);

    html = `Have you tried clicking the <kbd>Help Me!</kbd> button?`;
    assert.strictEqual(toMarkdown(html), html);

    html = `<mark>This is highlighted!</mark>`;
    assert.strictEqual(toMarkdown(html), html);

    html = `Lorem <a href="http://example.com"><del>ipsum \n\n\n dolor</del> sit.</a>`;
    output = `Lorem [<del>ipsum dolor</del> sit.](http://example.com)`;
    assert.strictEqual(toMarkdown(html), output);
  });

  test("converts code tags", function (assert) {
    let html = `Lorem ipsum dolor sit amet,
  <pre><code>var helloWorld = () => {
  alert('    hello \t\t world    ');
    return;
}
helloWorld();</code></pre>
  consectetur.`;
    let output = `Lorem ipsum dolor sit amet,\n\n\`\`\`\nvar helloWorld = () => {\n  alert('    hello \t\t world    ');\n    return;\n}\nhelloWorld();\n\`\`\`\n\nconsectetur.`;

    assert.strictEqual(toMarkdown(html), output);

    html = `Lorem ipsum dolor sit amet, <code>var helloWorld = () => {
  alert('    hello \t\t world    ');
    return;
}
helloWorld();</code>consectetur.`;
    output = `Lorem ipsum dolor sit amet, \`var helloWorld = () => {\n  alert('    hello \t\t world    ');\n    return;\n}\nhelloWorld();\`consectetur.`;

    assert.strictEqual(toMarkdown(html), output);
  });

  test("converts blockquote tag", function (assert) {
    let html = "<blockquote>Lorem ipsum</blockquote>";
    let output = "> Lorem ipsum";
    assert.strictEqual(toMarkdown(html), output);

    html =
      "<blockquote>Lorem ipsum</blockquote><blockquote><p>dolor sit amet</p></blockquote>";
    output = "> Lorem ipsum\n\n> dolor sit amet";
    assert.strictEqual(toMarkdown(html), output);

    html =
      "<blockquote>\nLorem ipsum\n<blockquote><p>dolor <blockquote>sit</blockquote> amet</p></blockquote></blockquote>";
    output = "> Lorem ipsum\n> > dolor\n> > > sit\n> > amet";
    assert.strictEqual(toMarkdown(html), output);
  });

  test("converts ol list tag", function (assert) {
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
    assert.strictEqual(toMarkdown(html), markdown);
  });

  test("converts list tag from word", function (assert) {
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
    assert.strictEqual(toMarkdown(html), markdown);
  });

  test("keeps mention/hash class", function (assert) {
    const html = `
      <p>User mention: <a class="mention" href="/u/discourse">@discourse</a></p>
      <p>Group mention: <a class="mention-group" href="/groups/discourse">@discourse-group</a></p>
      <p>Category link: <a class="hashtag" href="/c/foo/1">#<span>foo</span></a></p>
      <p>Sub-category link: <a class="hashtag" href="/c/foo/bar/2">#<span>foo:bar</span></a></p>
    `;

    const markdown = `User mention: @discourse\n\nGroup mention: @discourse-group\n\nCategory link: #foo\n\nSub-category link: #foo:bar`;

    assert.strictEqual(toMarkdown(html), markdown);
  });

  test("strips user status from mentions", function (assert) {
    const statusHtml = `
        <img class="emoji user-status"
             src="/images/emoji/twitter/desert_island.png?v=12"
             title="vacation">
    `;
    const html = `Mentioning <a class="mention" href="/u/andrei">@andrei${statusHtml}</a>`;
    const expectedMarkdown = `Mentioning @andrei`;

    assert.strictEqual(toMarkdown(html), expectedMarkdown);
  });

  test("keeps hashtag-cooked and converts to bare hashtag with type", function (assert) {
    const html = `
      <p dir="ltr">This is <a class="hashtag-cooked" href="/c/ux/14" data-type="category" data-slug="ux">
      <svg class="fa d-icon d-icon-folder svg-icon svg-node">
        <use href="#folder"></use>
      </svg>
      <span>ux</span>
      </a> and <a class="hashtag-cooked" href="/tag/design" data-slug="design">
      <svg class="fa d-icon d-icon-tag svg-icon svg-node">
        <use href="#tag"></use>
      </svg>
      <span>design</span>
      </a> and <a class="hashtag-cooked" href="/c/uncategorized/design/22" data-type="category" data-slug="design" data-ref="uncategorized:design">
      <svg class="fa d-icon d-icon-folder svg-icon svg-node">
        <use href="#folder"></use>
      </svg>
      <span>design</span>
      </a></p>
    `;

    const markdown = `This is #ux::category and #design and #uncategorized:design`;
    assert.strictEqual(toMarkdown(html), markdown);
  });

  test("keeps emoji and removes click count", function (assert) {
    const html = `
      <p>
        A <a href="http://example.com">link</a><span class="badge badge-notification clicks" title="1 click">1</span> with click count
        and <img class="emoji" title=":boom:" src="https://d11a6trkgmumsb.cloudfront.net/images/emoji/twitter/boom.png?v=5" alt=":boom:" /> emoji.
      </p>
    `;

    const markdown = `A [link](http://example.com) with click count and :boom: emoji.`;

    assert.strictEqual(toMarkdown(html), markdown);
  });

  test("keeps emoji syntax for custom emoji", function (assert) {
    const html = `
      <p>
        <img class="emoji emoji-custom" title=":custom_emoji:" src="https://d11a6trkgmumsb.cloudfront.net/images/emoji/custom_emoji" alt=":custom_emoji:" />
      </p>
    `;

    const markdown = `:custom_emoji:`;

    assert.strictEqual(toMarkdown(html), markdown);
  });

  test("converts image lightboxes to markdown", function (assert) {
    let html = `
    <a class="lightbox" href="https://d11a6trkgmumsb.cloudfront.net/uploads/default/original/1X/8hkjhk7692f6afed3cb99d43ab2abd4e30aa8cba.jpeg" data-download-href="https://d11a6trkgmumsb.cloudfront.net/uploads/default/8hkjhk7692f6afed3cb99d43ab2abd4e30aa8cba" title="sherlock3_sig.jpg" rel="nofollow noopener"><img src="https://d11a6trkgmumsb.cloudfront.net/uploads/default/optimized/1X/8hkjhk7692f6afed3cb99d43ab2abd4e30aa8cba_2_689x459.jpeg" alt="sherlock3_sig" width="689" height="459" class="d-lazyload" srcset="https://d11a6trkgmumsb.cloudfront.net/uploads/default/optimized/1X/8hkjhk7692f6afed3cb99d43ab2abd4e30aa8cba_2_689x459.jpeg, https://d11a6trkgmumsb.cloudfront.net/uploads/default/optimized/1X/8hkjhk7692f6afed3cb99d43ab2abd4e30aa8cba_2_1033x688.jpeg 1.5x, https://d11a6trkgmumsb.cloudfront.net/uploads/default/optimized/1X/8hkjhk7692f6afed3cb99d43ab2abd4e30aa8cba_2_1378x918.jpeg 2x"><div class="meta">
    <span class="filename">sherlock3_sig.jpg</span><span class="informations">5496×3664 2 MB</span><span class="expand"></span>
    </div></a>
    `;
    let markdown = `![sherlock3_sig.jpg](https://d11a6trkgmumsb.cloudfront.net/uploads/default/original/1X/8hkjhk7692f6afed3cb99d43ab2abd4e30aa8cba.jpeg)`;

    assert.strictEqual(toMarkdown(html), markdown);

    html = `<a class="lightbox" href="https://d11a6trkgmumsb.cloudfront.net/uploads/default/original/1X/8hkjhk7692f6afed3cb99d43ab2abd4e30aa8cba.jpeg" data-download-href="https://d11a6trkgmumsb.cloudfront.net/uploads/default/8hkjhk7692f6afed3cb99d43ab2abd4e30aa8cba" title="sherlock3_sig.jpg" rel="nofollow noopener"><img src="https://d11a6trkgmumsb.cloudfront.net/uploads/default/optimized/1X/8hkjhk7692f6afed3cb99d43ab2abd4e30aa8cba_2_689x459.jpeg" alt="sherlock3_sig" width="689" height="459" class="d-lazyload" srcset="https://d11a6trkgmumsb.cloudfront.net/uploads/default/optimized/1X/8hkjhk7692f6afed3cb99d43ab2abd4e30aa8cba_2_689x459.jpeg, https://d11a6trkgmumsb.cloudfront.net/uploads/default/optimized/1X/8hkjhk7692f6afed3cb99d43ab2abd4e30aa8cba_2_1033x688.jpeg 1.5x, https://d11a6trkgmumsb.cloudfront.net/uploads/default/optimized/1X/8hkjhk7692f6afed3cb99d43ab2abd4e30aa8cba_2_1378x918.jpeg 2x"></a>`;

    assert.strictEqual(toMarkdown(html), markdown);

    html = `
    <a class="lightbox" href="https://d11a6trkgmumsb.cloudfront.net/uploads/default/original/1X/8hkjhk7692f6afed3cb99d43ab2abd4e30aa8cba.jpeg" data-download-href="https://d11a6trkgmumsb.cloudfront.net/uploads/default/8hkjhk7692f6afed3cb99d43ab2abd4e30aa8cba" title="sherlock3_sig.jpg" rel="nofollow noopener"><img src="https://d11a6trkgmumsb.cloudfront.net/uploads/default/optimized/1X/8hkjhk7692f6afed3cb99d43ab2abd4e30aa8cba_2_689x459.jpeg" data-base62-sha1="1frsimI7TOtFJyD2LLyKSHM8JWe" alt="sherlock3_sig" width="689" height="459" class="d-lazyload" srcset="https://d11a6trkgmumsb.cloudfront.net/uploads/default/optimized/1X/8hkjhk7692f6afed3cb99d43ab2abd4e30aa8cba_2_689x459.jpeg, https://d11a6trkgmumsb.cloudfront.net/uploads/default/optimized/1X/8hkjhk7692f6afed3cb99d43ab2abd4e30aa8cba_2_1033x688.jpeg 1.5x, https://d11a6trkgmumsb.cloudfront.net/uploads/default/optimized/1X/8hkjhk7692f6afed3cb99d43ab2abd4e30aa8cba_2_1378x918.jpeg 2x"><div class="meta">
    <span class="filename">sherlock3_sig.jpg</span><span class="informations">5496×3664 2 MB</span><span class="expand"></span>
    </div></a>
    `;
    markdown = `![sherlock3_sig.jpg](upload://1frsimI7TOtFJyD2LLyKSHM8JWe)`;

    assert.strictEqual(toMarkdown(html), markdown);
  });

  test("converts quotes to markdown", function (assert) {
    let html = `
    <p>there is a quote below</p>
    <aside class="quote no-group" data-username="foo" data-post="1" data-topic="2">
    <div class="title" style="cursor: pointer;">
    <div class="quote-controls"><span class="svg-icon-title" title="expand/collapse"><svg class="fa d-icon d-icon-chevron-down svg-icon svg-string" xmlns="http://www.w3.org/2000/svg"><use href="#chevron-down"></use></svg></span><a href="/t/hello-world-i-am-posting-an-image/158/1" title="go to the quoted post" class="back"><svg class="fa d-icon d-icon-arrow-up svg-icon svg-string" xmlns="http://www.w3.org/2000/svg"><use href="#arrow-up"></use></svg></a></div>
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

    assert.strictEqual(toMarkdown(html), markdown.trim());
  });

  test("converts nested quotes to markdown", function (assert) {
    let html = `
      <aside class="quote no-group">
        <blockquote>
          <aside class="quote no-group">
            <blockquote>
              <p dir="ltr">test</p>
            </blockquote>
          </aside>
          <p dir="ltr">test2</p>
        </blockquote>
      </aside>
    `;

    let markdown = `
[quote]
[quote]
test
[/quote]

test2
[/quote]
`;

    assert.strictEqual(toMarkdown(html), markdown.trim());
  });

  test("strips base64 image URLs", function (assert) {
    const html =
      '<img src="data:image/jpeg;base64,/9j/4AAQSkZJRgABAgAAZABkAAD/7AARRHVja3kAAQAEAAAAPAAA/+4AJkFkb2JlAGTAAAAAAQMAFQQDBgoNAAABywAAAgsAAAJpAAACyf/bAIQABgQEBAUEBgUFBgkGBQYJCwgGBggLDAoKCwoKDBAMDAwMDAwQDA4PEA8ODBMTFBQTExwbGxscHx8fHx8fHx8fHwEHBwcNDA0YEBAYGhURFRofHx8fHx8fHx8fHx8fHx8fHx8fHx8fHx8fHx8fHx8fHx8fHx8fHx8fHx8fHx8fHx8f/8IAEQgAEAAQAwERAAIRAQMRAf/EAJQAAQEBAAAAAAAAAAAAAAAAAAMFBwEAAwEAAAAAAAAAAAAAAAAAAAEDAhAAAQUBAQAAAAAAAAAAAAAAAgABAwQFESARAAIBAwIHAAAAAAAAAAAAAAERAgAhMRIDQWGRocEiIxIBAAAAAAAAAAAAAAAAAAAAIBMBAAMAAQQDAQAAAAAAAAAAAQARITHwQVGBYXGR4f/aAAwDAQACEQMRAAAB0UlMciEJn//aAAgBAQABBQK5bGtFn6pWi2K12wWTRkjb/9oACAECAAEFAvH/2gAIAQMAAQUCIuIJOqRndRiv/9oACAECAgY/Ah//2gAIAQMCBj8CH//aAAgBAQEGPwLWQzwHepfNbcUNfM4tUIbA9QL4AvnxTlAxacpWJReOlf/aAAgBAQMBPyHZDveuCyu4B4lz2lDKto2ca5uclPK0aoq32x8xgTSLeSgbyzT65n//2gAIAQIDAT8hlQjP/9oACAEDAwE/IaE9GcZFJ//aAAwDAQACEQMRAAAQ5F//2gAIAQEDAT8Q1oowKccI3KTdAWkPLw2ssIrwKYUzuJoUJsIHOCoG23ISlja+rU9QvCx//9oACAECAwE/EAuNIiKf/9oACAEDAwE/ECujJzHf7iwHOv5NhK+8efH50z//2Q==" />';
    assert.strictEqual(toMarkdown(html), "[image]");
  });

  test("addTagDecorateCallback", function (assert) {
    const html = `<span class="loud">HELLO THERE</span>`;

    addTagDecorateCallback(function (text) {
      if (this.element.attributes.class === "loud") {
        this.prefix = "^^";
        this.suffix = "^^";
        return text.toLowerCase();
      }
    });

    assert.strictEqual(toMarkdown(html), "^^hello there^^");
  });

  test("addBlockDecorateCallback", function (assert) {
    const html = `<div class="quiet">hey<br>there</div>`;

    addBlockDecorateCallback(function () {
      if (this.element.attributes.class === "quiet") {
        this.prefix = "[quiet]";
        this.suffix = "[/quiet]";
      }
    });

    assert.strictEqual(toMarkdown(html), "[quiet]hey\nthere[/quiet]");
  });

  test("converts inline mathjax", function (assert) {
    const html = `<p>Lorem ipsum <span class="math" data-applied-mathjax="true" style="display: none;">E=mc^2</span><span class="math-container,inline-math,mathjax-math" style=""><span id="MathJax-Element-1-Frame" class="mjx-chtml MathJax_CHTML" tabindex="0" style="font-size: 117%;"><span id="MJXc-Node-1" class="mjx-math"><span id="MJXc-Node-2" class="mjx-mrow"><span id="MJXc-Node-3" class="mjx-mi"><span class="mjx-char MJXc-TeX-math-I" style="padding-top: 0.483em; padding-bottom: 0.27em; padding-right: 0.026em;">E</span></span><span id="MJXc-Node-4" class="mjx-mo MJXc-space3"><span class="mjx-char MJXc-TeX-main-R" style="padding-top: 0.056em; padding-bottom: 0.323em;">=</span></span><span id="MJXc-Node-5" class="mjx-mi MJXc-space3"><span class="mjx-char MJXc-TeX-math-I" style="padding-top: 0.216em; padding-bottom: 0.27em;">m</span></span><span id="MJXc-Node-6" class="mjx-msubsup"><span class="mjx-base"><span id="MJXc-Node-7" class="mjx-mi"><span class="mjx-char MJXc-TeX-math-I" style="padding-top: 0.216em; padding-bottom: 0.27em;">c</span></span></span><span class="mjx-sup" style="font-size: 70.7%; vertical-align: 0.513em; padding-left: 0px; padding-right: 0.071em;"><span id="MJXc-Node-8" class="mjx-mn" style=""><span class="mjx-char MJXc-TeX-main-R" style="padding-top: 0.377em; padding-bottom: 0.323em;">2</span></span></span></span></span></span></span><script type="math/tex" id="MathJax-Element-1">E=mc^2</script></span> dolor sit amet.</p>`;
    const markdown = `Lorem ipsum $E=mc^2$ dolor sit amet.`;
    assert.strictEqual(toMarkdown(html), markdown);
  });

  test("converts block mathjax", function (assert) {
    const html = `<p>Before</p>
    <div class="math" data-applied-mathjax="true" style="display: none;">
    \\sqrt{(-1)} \\; 2^3 \\; \\sum \\; \\pi
    </div><div class="math-container,block-math,mathjax-math" style=""><span class="mjx-chtml MJXc-display" style="text-align: center;"><span id="MathJax-Element-2-Frame" class="mjx-chtml MathJax_CHTML" tabindex="0" style="font-size: 117%; text-align: center;"><span id="MJXc-Node-9" class="mjx-math"><span id="MJXc-Node-10" class="mjx-mrow"><span id="MJXc-Node-11" class="mjx-msqrt"><span class="mjx-box" style="padding-top: 0.045em;"><span class="mjx-surd"><span class="mjx-char MJXc-TeX-size2-R" style="padding-top: 0.911em; padding-bottom: 0.911em;">√</span></span><span class="mjx-box" style="padding-top: 0.315em; border-top: 1.4px solid;"><span id="MJXc-Node-12" class="mjx-mrow"><span id="MJXc-Node-13" class="mjx-mo"><span class="mjx-char MJXc-TeX-main-R" style="padding-top: 0.483em; padding-bottom: 0.59em;">(</span></span><span id="MJXc-Node-14" class="mjx-mo"><span class="mjx-char MJXc-TeX-main-R" style="padding-top: 0.323em; padding-bottom: 0.43em;">−</span></span><span id="MJXc-Node-15" class="mjx-mn"><span class="mjx-char MJXc-TeX-main-R" style="padding-top: 0.377em; padding-bottom: 0.323em;">1</span></span><span id="MJXc-Node-16" class="mjx-mo"><span class="mjx-char MJXc-TeX-main-R" style="padding-top: 0.483em; padding-bottom: 0.59em;">)</span></span></span></span></span></span><span id="MJXc-Node-17" class="mjx-mspace" style="width: 0.278em; height: 0px;"></span><span id="MJXc-Node-18" class="mjx-msubsup"><span class="mjx-base"><span id="MJXc-Node-19" class="mjx-mn"><span class="mjx-char MJXc-TeX-main-R" style="padding-top: 0.377em; padding-bottom: 0.323em;">2</span></span></span><span class="mjx-sup" style="font-size: 70.7%; vertical-align: 0.591em; padding-left: 0px; padding-right: 0.071em;"><span id="MJXc-Node-20" class="mjx-mn" style=""><span class="mjx-char MJXc-TeX-main-R" style="padding-top: 0.377em; padding-bottom: 0.377em;">3</span></span></span></span><span id="MJXc-Node-21" class="mjx-mspace" style="width: 0.278em; height: 0px;"></span><span id="MJXc-Node-22" class="mjx-mo MJXc-space1"><span class="mjx-char MJXc-TeX-size2-R" style="padding-top: 0.751em; padding-bottom: 0.751em;">∑</span></span><span id="MJXc-Node-23" class="mjx-mspace" style="width: 0.278em; height: 0px;"></span><span id="MJXc-Node-24" class="mjx-mi MJXc-space1"><span class="mjx-char MJXc-TeX-math-I" style="padding-top: 0.216em; padding-bottom: 0.27em; padding-right: 0.003em;">π</span></span></span></span></span></span><script type="math/tex; mode=display" id="MathJax-Element-2">\\sqrt{(-1)} \\; 2^3 \\; \\sum \\; \\pi</script></div>
    <p>After</p>`;

    const markdown = `Before

$$
\\sqrt{(-1)} \\; 2^3 \\; \\sum \\; \\pi
$$

After`;

    assert.strictEqual(toMarkdown(html), markdown);
  });
});
