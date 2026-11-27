import { closeBrackets, CompletionContext } from "@codemirror/autocomplete";
import { toggleComment } from "@codemirror/commands";
import {
  ensureSyntaxTree,
  foldable,
  getIndentation,
} from "@codemirror/language";
import { EditorSelection, EditorState } from "@codemirror/state";
import { EditorView, runScopeHandlers } from "@codemirror/view";
import { module, test } from "qunit";
import liquidLanguage from "discourse/static/codemirror/languages/liquid";

const SCOPE = {
  site: { title: "Example" },
  articles: [{ title: "First", tags: [{ name: "news" }] }],
  inputs: [[{ name: "Alice" }], [], [{ email: "alice@example.com" }]],
};

function complete(doc, options = {}, { explicit = false } = {}) {
  const created = EditorState.create({
    doc,
    extensions: liquidLanguage({}, { scope: SCOPE, ...options }),
  });
  ensureSyntaxTree(created, doc.length, 5000);
  // The tree parsed above is what the next state reads.
  const state = created.update({}).state;
  const context = new CompletionContext(state, doc.length, explicit);

  return (
    state
      .languageDataAt("autocomplete", doc.length)
      .map((source) => source(context))
      .find(Boolean) ?? null
  );
}

function treeErrors(tree) {
  let errors = 0;
  tree.iterate({
    enter: (node) => {
      errors += node.type.isError ? 1 : 0;
    },
  });
  return errors;
}

function parseErrors(state) {
  return treeErrors(ensureSyntaxTree(state, state.doc.length, 5000));
}

function liquidState(doc) {
  return EditorState.create({ doc, extensions: liquidLanguage({}) });
}

function editor(doc, extensions) {
  return new EditorView({
    state: EditorState.create({
      doc,
      selection: { anchor: doc.length },
      extensions,
    }),
  });
}

function labels(result) {
  return result?.options.map((candidate) => candidate.label) ?? [];
}

function option(result, label) {
  return result.options.find((candidate) => candidate.label === label);
}

// Each keystroke goes through the editor's input handlers, as typing does.
function type(view, text) {
  for (const char of text) {
    const { from, to } = view.state.selection.main;
    const handled = view.state
      .facet(EditorView.inputHandler)
      .some((handler) => handler(view, from, to, char, () => null));
    if (!handled) {
      view.dispatch(view.state.replaceSelection(char));
    }
  }
}

module("Unit | Static | CodeMirror | liquid", function () {
  test("offers nothing in the text around tags", function (assert) {
    assert.strictEqual(complete("<p>Items: "), null);
    assert.strictEqual(complete("Items: ", { base: "text" }), null);
  });

  test("completes the context's variables once a word is started", function (assert) {
    assert.deepEqual(labels(complete("{{ si")), ["site", "articles", "inputs"]);
    assert.strictEqual(complete("{{ "), null, "not before a word");
    assert.true(
      labels(complete("{{ ", {}, { explicit: true })).includes("site"),
      "unless asked"
    );
  });

  test("reads a context function on every completion", function (assert) {
    let scope = { before: 1 };
    const options = { scope: () => scope };

    assert.deepEqual(labels(complete("{{ b", options)), ["before"]);
    scope = { after: 1 };
    assert.deepEqual(labels(complete("{{ a", options)), ["after"]);
  });

  test("completes properties by path", function (assert) {
    assert.deepEqual(labels(complete("{{ site.")), ["title"]);
    assert.deepEqual(labels(complete("{{ articles.")), [
      "first",
      "last",
      "size",
    ]);
    assert.deepEqual(
      labels(complete("{{ articles.first.")),
      ["title", "tags"],
      "a list's elements share a shape"
    );
    assert.deepEqual(
      labels(complete("{{ inputs[2][0].")),
      ["email"],
      "an index picks its element when there is one"
    );
    assert.strictEqual(complete("{{ nope."), null);
  });

  test("binds loop variables to an element of their collection", function (assert) {
    const loop = "{% for article in articles %}";

    assert.deepEqual(labels(complete(`${loop}{{ article.`)), ["title", "tags"]);
    assert.deepEqual(
      labels(complete(`${loop}{% for tag in article.tags %}{{ tag.`)),
      ["name"],
      "through an enclosing loop"
    );
    assert.deepEqual(
      labels(complete(`${loop}${"a".repeat(4000)}{{ article.`)),
      ["title", "tags"],
      "in a long template"
    );
    assert.true(
      labels(complete(`${loop}{{ art`)).includes("article"),
      "at the root"
    );
    assert.true(labels(complete(`${loop}{{ for`)).includes("forloop"));
    assert.true(
      labels(complete(`${loop}{{ forloop.`)).includes("index"),
      "with its helper object"
    );
    assert.false(
      labels(complete(`${loop}{% endfor %}{{ art`)).includes("article"),
      "only inside the loop"
    );
    assert.true(
      labels(
        complete("{% for post in posts %}{{ po", { scope: { posts: [] } })
      ).includes("post"),
      "even when the example list is empty"
    );
    for (const doc of [
      "{% for i in (1..3) %}{{ i",
      "{% for i in nope %}{{ i",
    ]) {
      assert.strictEqual(
        option(complete(doc), "i").apply,
        undefined,
        `without a dot when its value is unknown: ${doc}`
      );
    }
  });

  test("binds what assign and capture set once they are done", function (assert) {
    assert.deepEqual(
      labels(complete("{% assign top = articles.first %}{{ top.")),
      ["title", "tags"],
      "an assigned path"
    );
    assert.deepEqual(
      labels(
        complete(
          "{% for a in articles %}{% assign t = a.tags %}{% endfor %}" +
            "{% for tag in t %}{{ tag."
        )
      ),
      ["name"],
      "through the loop around the assign"
    );
    assert.strictEqual(
      option(complete("{% assign t = site.title | upcase %}{{ t"), "t").apply,
      undefined,
      "a filtered value is unknown"
    );
    assert.true(
      labels(complete("{% capture intro %}x{% endcapture %}{{ intr")).includes(
        "intro"
      ),
      "a capture after its block"
    );
    assert.false(
      labels(complete("{% capture intro %}{{ intr")).includes("intro"),
      "not inside it"
    );
    assert.false(
      labels(complete("{% assign later = ", {}, { explicit: true })).includes(
        "later"
      ),
      "an assign is not offered inside its own tag"
    );
  });

  test("keeps assignments from a large loop available after it ends", function (assert) {
    const assignments = Array.from(
      { length: 1500 },
      (_, index) => `{% assign item${index} = article %}`
    ).join("");
    const doc = `{% for article in articles %}${assignments}{% endfor %}`;

    assert.deepEqual(
      labels(complete(`${doc}{{ item1499.`)),
      ["title", "tags"],
      "the last assignment retains the loop element's properties"
    );
    const result = labels(complete(`${doc}{{ item`));
    assert.true(result.includes("item0"), "the first assignment is retained");
    assert.true(result.includes("item1499"), "the last assignment is retained");
    assert.false(result.includes("article"), "the loop binding does not leak");
  });

  test("loop bindings shadow values and aliases without changing the outer scope", function (assert) {
    const prefix = "{% assign entry = site %}";
    const loop = "{% for entry in articles %}";
    assert.deepEqual(
      labels(complete(`${prefix}${loop}{{ entry.`)),
      ["title", "tags"],
      "the loop element shadows the assigned object"
    );
    assert.deepEqual(
      labels(complete(`${prefix}${loop}{% endfor %}{{ entry.`)),
      ["title"],
      "the outer object is still available after the loop"
    );

    const paths = [];
    complete(`${prefix}{% for entry in (1..3) %}{{ ent`, {
      describe: (path) => void paths.push(path.join(".")),
    });
    assert.true(
      paths.includes("entry"),
      "an unknown loop value hides the outer alias"
    );
    assert.strictEqual(
      complete("{% for entry in articles %}{{ constructor."),
      null,
      "scope inheritance does not expose Object.prototype"
    );
  });

  test("completes names that objects already have", function (assert) {
    assert.strictEqual(
      complete("{% assign constructor = 1 %}{{ constructor."),
      null,
      "an assigned name"
    );
    assert.deepEqual(
      labels(
        complete("{{ constructor.", {
          scope: { constructor: { name: "Example" } },
        })
      ),
      ["name"],
      "a name in the scope"
    );

    const paths = [];
    complete("{% assign toString = 1 %}{{ toS", {
      describe: (path) => void paths.push(path),
    });
    assert.deepEqual(
      paths.find((path) => path[0] === "toString"),
      ["toString"],
      "described by its own path"
    );
    assert.true(paths.every(Array.isArray), "every path is a list");
  });

  test("lets the caller describe or hide a path", function (assert) {
    const result = complete("{{ site.", {
      scope: { site: { title: "Example", secret: "x" } },
      describe: (path) =>
        path.join(".") === "site.secret" ? null : { detail: path.join(".") },
    });

    assert.deepEqual(labels(result), ["title"]);
    assert.strictEqual(option(result, "title").detail, "site.title");
  });

  test("describes a path as it reads from the root of the scope", function (assert) {
    const described = (doc) => {
      const paths = [];
      complete(doc, {
        describe: (path) => {
          paths.push(path.join("."));
        },
      });
      return paths;
    };
    const loop = "{% for article in articles %}";

    for (const doc of [
      "{{ articles.first.",
      "{{ articles.last.",
      "{{ articles[0].",
      `${loop}{{ article.`,
      "{% assign top = articles.first %}{{ top.",
      `${loop}{{ article["tags"].first.name | x }}{{ article.`,
    ]) {
      assert.deepEqual(
        described(doc),
        ["articles.[].title", "articles.[].tags"],
        doc
      );
    }
    assert.deepEqual(
      described(`${loop}{% for tag in article.tags %}{{ tag.`),
      ["articles.[].tags.[].name"],
      "through an enclosing loop"
    );
    assert.true(
      described(`${loop}{{ art`).includes("articles.[]"),
      "a loop variable at the root"
    );
  });

  test("tells the caller whether a path is completed as a variable", function (assert) {
    const described = (doc, explicit = false) => {
      const found = [];
      complete(
        doc,
        {
          describe: (path, value, { variable }) =>
            void found.push(`${path.join(".")}:${variable}`),
        },
        { explicit }
      );
      return found;
    };

    assert.deepEqual(described("{{ site."), ["site.title:false"], "a property");
    assert.true(
      described("{% assign name = site.title %}{{ ", true).includes(
        "site.title:true"
      ),
      "an assign of a property"
    );
  });

  test("reads a key that is not a name with a subscript", function (assert) {
    const scope = {
      data: { "my key": { a: 1 }, "it's": 1, [`"both's"`]: 1, plain: 1 },
      "top level": 1,
    };
    const result = complete("{{ data.", { scope });

    assert.deepEqual(labels(result), ["my key", "it's", "plain"]);
    assert.false(
      labels(complete("{{ ", { scope }, { explicit: true })).includes(
        "top level"
      ),
      "not at the root, where there is no object to subscript"
    );

    const pick = (label) => {
      const view = editor("{{ data.", []);
      const picked = option(result, label);
      picked.apply(view, picked, result.from, view.state.doc.length);
      const doc = view.state.doc.toString();
      view.destroy();
      return doc;
    };
    assert.strictEqual(pick("my key"), '{{ data["my key"].');
    assert.strictEqual(pick("it's"), '{{ data["it\'s"]');
    assert.strictEqual(
      option(result, "plain").apply,
      undefined,
      "a name is inserted as is"
    );
  });

  test("uses the caller's section without changing Liquid insertion", function (assert) {
    const section = { name: "Blog fields", rank: 4 };
    const result = complete("{{ s", {
      scope: { site: {}, secret: "" },
      describe: () => ({
        section,
        detail: "Example",
        label: "wrong",
        type: "keyword",
        apply: "wrong",
      }),
    });

    const site = option(result, "site");
    assert.strictEqual(site.section, section, "the caller owns the section");
    assert.strictEqual(
      site.detail,
      "Example",
      "metadata describes the candidate"
    );
    assert.strictEqual(
      site.type,
      "variable",
      "Liquid owns the completion type"
    );
    const view = editor("{{ s", []);
    site.apply(view, site, result.from, view.state.doc.length);
    assert.strictEqual(
      view.state.doc.toString(),
      "{{ site.",
      "metadata cannot replace the label or path insertion"
    );
    view.destroy();
  });

  test("offers the tags a caller allows, with their block tags", function (assert) {
    const result = complete("{% i", { tags: ["if", "assign"] });

    assert.deepEqual(labels(result), [
      "if",
      "elsif",
      "else",
      "endif",
      "assign",
    ]);
    assert.strictEqual(option(result, "if").apply, "if ", "room for arguments");
    assert.strictEqual(option(result, "endif").apply, "endif");
    assert.true(
      labels(complete("{% i")).includes("render"),
      "standard Liquid by default"
    );
    assert.true(
      labels(complete("{% for")).includes("for"),
      "once the keyword is complete"
    );
    assert.true(
      labels(complete("{%- fo")).includes("for"),
      "after whitespace control"
    );
    assert.true(
      labels(complete("{% ")).includes("if"),
      "before a name is started"
    );
  });

  test("offers the filters a caller allows", function (assert) {
    const result = complete("{{ site.title | up", {
      filters: ["upcase", "squish"],
    });

    assert.deepEqual(labels(result), ["upcase", "squish"]);
    assert.true(
      labels(complete("{{ site.title | up")).includes("where"),
      "standard Liquid by default"
    );
    assert.true(
      labels(complete("{{ site.title | ")).includes("where"),
      "before a name is started"
    );
    assert.strictEqual(
      option(complete("{{ x | tr"), "truncate").detail,
      "(length)"
    );
  });

  test("comments out a line as Liquid", function (assert) {
    const toggled = (doc, line, base, lastLine = line) => {
      const view = editor(doc, liquidLanguage({}, { base }));
      view.dispatch({
        selection: {
          anchor: view.state.doc.line(line).from,
          head: view.state.doc.line(lastLine).to,
        },
      });
      toggleComment(view);
      const result = view.state.doc.toString();
      view.destroy();
      return result;
    };

    for (const base of ["html", "text"]) {
      assert.strictEqual(
        toggled("{% if x %}", 1, base),
        "{% comment %} {% if x %} {% endcomment %}",
        `a tag on ${base}`
      );
    }
    assert.strictEqual(
      toggled("<p>{{ x }}</p>", 1, "html"),
      "{% comment %} <p>{{ x }}</p> {% endcomment %}",
      "markup, where an HTML comment would still run the Liquid"
    );
    assert.strictEqual(
      toggled("{% liquid\nassign x = 1\n%}", 2, "html"),
      "{% liquid\n# assign x = 1\n%}",
      "a statement in a liquid tag"
    );
    assert.strictEqual(
      toggled("{%- liquid\nassign x = 1\n-%}", 2, "html"),
      "{%- liquid\n# assign x = 1\n-%}",
      "with whitespace control"
    );

    const liquidTag = "{% liquid\nassign x = 1\n%}";
    assert.strictEqual(
      toggled(liquidTag, 1, "html"),
      liquidTag,
      "not the line that opens a liquid tag"
    );
    assert.strictEqual(
      toggled(liquidTag, 3, "html"),
      liquidTag,
      "nor the line that closes it"
    );
    assert.strictEqual(
      toggled(liquidTag, 2, "html", 3),
      liquidTag,
      "nor a statement selected with it"
    );
    assert.strictEqual(
      toggled(liquidTag, 1, "html", 3),
      `{% comment %} ${liquidTag} {% endcomment %}`,
      "the whole tag as a block"
    );
    assert.strictEqual(
      toggled("{% liquid echo x %}", 1, "html"),
      "{% comment %} {% liquid echo x %} {% endcomment %}",
      "a liquid tag on one line"
    );
  });

  test("reads whitespace control dashes", function (assert) {
    for (const doc of [
      "{{- site.title -}}",
      "{% if site %}x{% endif-%}",
      "{%- raw -%}{{ x }}{%- endraw -%}",
      "{%- comment -%}x{%- endcomment -%}",
    ]) {
      assert.strictEqual(parseErrors(liquidState(doc)), 0, doc);
    }

    const typedDash = liquidState("{{ site.title }}").update({
      changes: { from: 2, insert: "-" },
    }).state;
    assert.strictEqual(parseErrors(typedDash), 0, "after a dash is typed");
  });

  test("reads whitespace control split across input chunks", function (assert) {
    const { parser } = liquidLanguage({}).language;
    const docs = [
      "{{- site.title -}}",
      "{{ x -}}",
      "{% if x %}a{% endif-%}",
      "{%- if x -%}a{%- endif -%}",
    ];

    for (const doc of docs) {
      for (let size = 1; size <= 4; size++) {
        const input = {
          length: doc.length,
          lineChunks: false,
          chunk: (from) => doc.slice(from, from + size),
          read: (from, to) => doc.slice(from, to),
        };
        assert.strictEqual(
          treeErrors(parser.parse(input)),
          0,
          `${doc} in chunks of ${size}`
        );
      }
    }
  });

  test("completes inside tags with whitespace control", function (assert) {
    assert.deepEqual(labels(complete("{{- site.")), ["title"]);
    assert.deepEqual(
      labels(complete("{{- site.title | up", { filters: ["upcase"] })),
      ["upcase"]
    );
    assert.true(labels(complete("{%- i")).includes("if"));
  });

  test("folds and indents Liquid blocks", function (assert) {
    const state = liquidState("{%- if x -%}\na\n{%- endif -%}");
    const first = state.doc.line(1);

    assert.notStrictEqual(foldable(state, first.from, first.to), null);
    assert.strictEqual(getIndentation(state, state.doc.line(2).from), 2);
  });

  test("offers nothing where a tag declares a name", function (assert) {
    for (const doc of [
      "{% for ar",
      "{% tablerow ar",
      "{% assign ar",
      "{% capture ar",
    ]) {
      assert.strictEqual(complete(doc), null, doc);
      assert.strictEqual(
        complete(doc.replace(/ar$/, ""), {}, { explicit: true }),
        null,
        `${doc} before the name`
      );
    }
    assert.true(
      labels(complete("{% for a in ar")).includes("articles"),
      "the collection still completes"
    );
    assert.true(
      labels(complete("{% assign a = ar")).includes("articles"),
      "as does the assigned value"
    );
  });

  test("offers nothing inside comments and strings", function (assert) {
    assert.strictEqual(complete("{% comment %}si"), null);
    assert.strictEqual(complete("{% # si"), null);
    assert.strictEqual(complete("{{ 'si"), null);
  });

  test("groups tags and filters under headings", function (assert) {
    assert.strictEqual(option(complete("{% i"), "if").section.name, "Tags");
    assert.strictEqual(
      option(complete("{{ x | up"), "upcase").section.name,
      "Filters"
    );
  });

  // Typed after text, where the markup's own brackets close as well.
  function eachBase(assert, callback) {
    for (const [base, text] of [
      ["html", "<p>"],
      ["text", "Items: "],
    ]) {
      const view = new EditorView({
        state: EditorState.create({
          extensions: [liquidLanguage({}, { base }), closeBrackets()],
        }),
      });
      const typed = (after, keys) => {
        view.dispatch({
          changes: {
            from: 0,
            to: view.state.doc.length,
            insert: `${text}${after}`,
          },
          selection: { anchor: text.length },
        });
        type(view, keys);
        return view.state.doc.toString().slice(text.length);
      };

      callback(typed, base, view, text);
      view.destroy();
    }
  }

  test("closes an opening delimiter once", function (assert) {
    eachBase(assert, (typed, base) => {
      assert.strictEqual(typed("", "{{"), "{{  }}", `output tag on ${base}`);
      assert.strictEqual(typed("", "{%"), "{%  %}", `logic tag on ${base}`);
      assert.strictEqual(
        typed("}}", "{{"),
        "{{  }}",
        `an existing closer is reused on ${base}`
      );
      assert.strictEqual(
        typed("%}", "{%"),
        "{%  %}",
        `an existing tag closer is reused on ${base}`
      );
    });
  });

  test("steps over a closer typed by hand", function (assert) {
    eachBase(assert, (typed, base) => {
      for (const [keys, expected] of [
        ["{{ x }}", "{{ x }}"],
        ["{{x}}", "{{ x }}"],
        ["{% if x %}", "{% if x %}"],
        ["{% endif-%}", "{% endif-%}"],
      ]) {
        assert.strictEqual(typed("", keys), expected, `${keys} on ${base}`);
      }
      assert.strictEqual(
        typed(" }} }}", "x}"),
        "x} }} }}",
        `not a closer after the tag on ${base}`
      );
    });
  });

  test("closes delimiters at every cursor", function (assert) {
    const view = new EditorView({
      state: EditorState.create({
        doc: "a\nb",
        selection: EditorSelection.create([
          EditorSelection.cursor(1),
          EditorSelection.cursor(3),
        ]),
        extensions: [
          EditorState.allowMultipleSelections.of(true),
          liquidLanguage({}),
          closeBrackets(),
        ],
      }),
    });
    type(view, "{{x}}");

    assert.strictEqual(view.state.doc.toString(), "a{{ x }}\nb{{ x }}");
    assert.strictEqual(view.state.selection.ranges.length, 2);
    view.destroy();
  });

  test("deletes an empty pair as a whole", function (assert) {
    eachBase(assert, (typed, base, view, text) => {
      for (const keys of ["{{", "{%", "{{-", "{%-"]) {
        typed("", keys);
        runScopeHandlers(
          view,
          new KeyboardEvent("keydown", { key: "Backspace" }),
          "editor"
        );
        assert.strictEqual(
          view.state.doc.toString(),
          text,
          `${keys} on ${base}`
        );
      }
    });
  });

  test("trims both sides when a dash follows the opener", function (assert) {
    eachBase(assert, (typed, base) => {
      assert.strictEqual(typed("", "{{-"), "{{-  -}}", `output tag on ${base}`);
      assert.strictEqual(typed("", "{%-"), "{%-  -%}", `logic tag on ${base}`);
      assert.strictEqual(
        typed("", "{%- if x -%}"),
        "{%- if x -%}",
        `typed in full on ${base}`
      );
      assert.strictEqual(
        typed("", "{{ -1 }}"),
        "{{ -1 }}",
        `a minus after a space on ${base}`
      );
    });
  });
});
