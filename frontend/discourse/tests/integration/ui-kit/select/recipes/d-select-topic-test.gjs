import { tracked } from "@glimmer/tracking";
import { array, hash } from "@ember/helper";
import { click, fillIn, find, findAll, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { DSelect } from "discourse/tests/helpers/d-select-helper";
import DSelectTopic from "discourse/ui-kit/select/recipes/topics/d-select-topic";
import DSelectTopicList from "discourse/ui-kit/select/recipes/topics/d-select-topic-list";

const TOPICS = [
  { id: 3, title: "Dogs are great", fancy_title: "Dogs are great" },
  { id: 5, title: "Cats :smile:", fancy_title: "Cats :smile:" },
  { id: 8, title: "Closed birds", fancy_title: "Closed birds", closed: true },
];

/**
 * Answers topic search like the server: topics whose title has every word of the term, or whose
 * id is the term. Search filters such as `status:public` or `@sam` are left out of the match. Records
 * every request's params.
 */
function stubTopicSearch(topics = TOPICS) {
  const requests = [];
  pretender.get("/search/query", (request) => {
    requests.push(request.queryParams);
    const words = request.queryParams.term
      .toLowerCase()
      .split(/\s+/)
      .filter((word) => word && !word.includes(":") && !word.startsWith("@"));
    const found = topics.filter((topic) =>
      words.every(
        (word) =>
          topic.title.toLowerCase().includes(word) || String(topic.id) === word
      )
    );
    return response({
      topics: found,
      posts: found.map((topic) => ({ id: topic.id * 10, topic_id: topic.id })),
    });
  });
  return requests;
}

/** Answers the held-topic lookup by the ids it is sent, leaving out unknown ones. */
function stubTopicLookup(topics = TOPICS) {
  const requests = [];
  pretender.get("/topics/lookup.json", (request) => {
    const ids = []
      .concat(request.queryParams.topic_ids ?? [])
      .map((id) => parseInt(id, 10));
    requests.push(ids);
    return response({ topics: topics.filter((t) => ids.includes(t.id)) });
  });
  return requests;
}

/** The titles of the listed options, in order. */
function optionTitles() {
  return findAll("[role='option'] .d-topic-option__title").map((title) =>
    title.textContent.trim()
  );
}

module(
  "Integration | ui-kit | select | recipes | DSelectTopic",
  function (hooks) {
    setupRenderingTest(hooks);

    test("lists nothing before a term", async function (assert) {
      const requests = stubTopicSearch();

      await render(<template><DSelectTopic /></template>);
      await new DSelect().open();

      assert.deepEqual(requests, [], "nothing is searched");
      assert.deepEqual(optionTitles(), []);
      assert
        .dom(".d-select__min-chars")
        .doesNotExist("no keep-typing hint: any term searches");
    });

    test("searches regular topics by title, URL or id with a term", async function (assert) {
      const requests = stubTopicSearch();

      await render(<template><DSelectTopic /></template>);
      const select = new DSelect();
      await select.open();
      await select.search("dogs");

      assert.deepEqual(requests, [
        {
          term: "dogs ",
          type_filter: "topic",
          search_for_id: "true",
          restrict_to_archetype: "regular",
        },
      ]);
      assert.deepEqual(optionTitles(), ["Dogs are great"]);
    });

    test("leaves out the excluded topics", async function (assert) {
      stubTopicSearch();
      const exclude = [3];

      await render(<template><DSelectTopic @exclude={{exclude}} /></template>);
      const select = new DSelect();
      await select.open();
      await select.search("e");

      assert.deepEqual(optionTitles(), ["Cats", "Closed birds"]);
    });

    test("additional filters list topics before a term, as a plain search", async function (assert) {
      const requests = stubTopicSearch();

      await render(
        <template><DSelectTopic @additionalFilters="status:public" /></template>
      );
      const select = new DSelect();
      await select.open();

      assert.deepEqual(requests, [{ term: " status:public" }]);
      assert.deepEqual(optionTitles(), [
        "Dogs are great",
        "Cats",
        "Closed birds",
      ]);
      assert
        .dom("[role='option'] .d-topic-option__title img.emoji")
        .exists("emoji codes in titles draw as emoji");

      await select.search("cats");

      assert.deepEqual(requests.at(-1), {
        term: "cats status:public",
        type_filter: "topic",
        search_for_id: "true",
        restrict_to_archetype: "regular",
      });
    });

    test("without an archetype, searches every topic the term finds", async function (assert) {
      const requests = stubTopicSearch();

      await render(<template><DSelectTopic @archetype={{null}} /></template>);
      const select = new DSelect();
      await select.open();
      await select.search("dogs");

      assert.deepEqual(requests, [
        { term: "dogs ", type_filter: "topic", search_for_id: "true" },
      ]);
    });

    test("searches messages, and is named for them", async function (assert) {
      const requests = stubTopicSearch();

      await render(
        <template><DSelectTopic @archetype="private_message" /></template>
      );
      const select = new DSelect();
      await select.open();
      await select.search("dogs");

      assert.deepEqual(requests, [
        {
          term: "dogs ",
          type_filter: "private_messages",
          search_for_id: "true",
          restrict_to_archetype: "private_message",
        },
      ]);
      assert.dom("[role='combobox']").hasAria("label", "Message");
      assert
        .dom("[role='combobox']")
        .hasAttribute("placeholder", "Type a message title, URL or ID");
    });

    test("draws each topic's status, title and category", async function (assert) {
      const category = this.owner.lookup("service:site").categories[0];
      stubTopicSearch([
        { ...TOPICS[2], category_id: category.id },
        { id: 9, title: "No category here", fancy_title: "No category here" },
      ]);

      await render(<template><DSelectTopic /></template>);
      const select = new DSelect();
      await select.open();
      await select.search("e");

      const [closed, plain] = findAll("[role='option']");
      assert.dom(".topic-status", closed).exists("the closed status shows");
      assert.dom(".d-topic-option__title", closed).hasText("Closed birds");
      assert
        .dom(".d-topic-option__category .badge-category__name", closed)
        .hasText(category.name);
      assert
        .dom(".d-topic-option__category", plain)
        .doesNotExist("a topic without a known category draws none");
    });

    test("sets a subcategory's badge apart from its parent's", async function (assert) {
      const subcategory = this.owner
        .lookup("service:site")
        .categories.find((category) => category.parent_category_id);
      stubTopicSearch([{ ...TOPICS[0], category_id: subcategory.id }]);

      await render(<template><DSelectTopic /></template>);
      const select = new DSelect();
      await select.open();
      await select.search("dogs");

      const badges = find("[role='option'] .d-topic-option__category");
      const [parent, child] = [
        ...badges.querySelectorAll(".badge-category__wrapper"),
      ].map((badge) => badge.getBoundingClientRect());
      // The test container is scaled, so measure in CSS pixels.
      const scale = badges.getBoundingClientRect().width / badges.offsetWidth;
      const gap = (child.left - parent.right) / scale;
      const halfEm = parseFloat(getComputedStyle(badges).fontSize) / 2;
      assert.true(
        gap >= halfEm - 0.5,
        `the badges are ${gap}px apart, half an em is ${halfEm}px`
      );
    });

    test("lines a title up with its category, and keeps a long one beside the status icons", async function (assert) {
      const category = this.owner.lookup("service:site").categories[0];
      const long = "Closed birds ".repeat(20).trim();
      stubTopicSearch([
        {
          id: 9,
          title: "Open birds",
          fancy_title: "Open birds",
          category_id: category.id,
        },
        { ...TOPICS[2], title: long, fancy_title: long },
      ]);

      // A list draws in place, so its width can be held to a narrow panel's.
      await render(
        <template>
          <div style="width: 300px"><DSelectTopicList /></div>
        </template>
      );
      await fillIn(".d-select.--list input[type='search']", "birds");

      const [open, closed] = findAll("[role='option']");
      const box = (selector, row) =>
        row.querySelector(selector).getBoundingClientRect();
      assert.strictEqual(
        box(".d-topic-option__title", open).left,
        box(".d-topic-option__category", open).left,
        "a topic without a status starts its title where its category starts"
      );
      const title = box(".d-topic-option__title", closed);
      const statuses = box(".topic-statuses", closed);
      assert.true(statuses.width > 0, "the closed topic shows its status");
      assert.true(
        title.top < statuses.bottom,
        `a long title starts on the status icons' line (title top ${title.top}, icons end at ${statuses.bottom})`
      );
      assert.true(
        title.left >= statuses.right,
        `a long title starts after the status icons (title left ${title.left}, icons end at ${statuses.right})`
      );
    });

    test("names itself for one topic or several, and invites a title, URL or id", async function (assert) {
      stubTopicSearch();

      await render(
        <template>
          <DSelectTopic class="one" />
          <DSelectTopic class="many" @multiple={{true}} />
        </template>
      );

      assert.dom(".one [role='combobox']").hasAria("label", "Topic");
      assert.dom(".many [role='combobox']").hasAria("label", "Topics");
      assert
        .dom(".one [role='combobox']")
        .hasAttribute("placeholder", "Type a topic title, URL or ID");
    });

    test("keeps the legacy family class", async function (assert) {
      await render(<template><DSelectTopic /></template>);

      assert.dom(".d-select").hasClass("topic-chooser");
    });

    test("looks the held topics up together", async function (assert) {
      const lookups = stubTopicLookup();

      await render(
        <template>
          <DSelectTopic @multiple={{true}} @value={{array 3 5}} />
        </template>
      );

      assert.deepEqual(lookups, [[3, 5]], "one lookup for every held id");
      assert.deepEqual(
        new DSelect().element().dataset.name,
        "Dogs are great,Cats :smile:"
      );
    });

    test("known held topics need no lookup", async function (assert) {
      const lookups = stubTopicLookup();
      const topics = [TOPICS[0]];

      await render(
        <template><DSelectTopic @topics={{topics}} @value={{3}} /></template>
      );

      assert.deepEqual(lookups, [], "nothing is looked up");
      assert.dom(".d-select").hasAttribute("data-name", "Dogs are great");
    });

    test("names a held topic nothing found by its id", async function (assert) {
      stubTopicLookup();
      const gone = ({ id }) => `Gone (${id})`;

      await render(
        <template>
          <DSelectTopic class="default" @value={{404}} />
          <DSelectTopic
            class="custom"
            @texts={{hash unresolved=gone}}
            @value={{405}}
          />
        </template>
      );

      assert.dom(".default").hasAttribute("data-name", "Topic #404");
      assert.dom(".custom").hasAttribute("data-name", "Gone (405)");
    });

    test("emits topic ids as numbers, with the topics", async function (assert) {
      stubTopicSearch();
      stubTopicLookup();
      const one = tracked(null);
      const many = tracked([3]);
      const changes = [];
      const setOne = (value, topic) => {
        changes.push(["one", value, topic?.title]);
        one.value = value;
      };
      const setMany = (value, topics) => {
        changes.push(["many", value, topics.map((topic) => topic.title)]);
        many.value = value;
      };

      await render(
        <template>
          <DSelectTopic class="one" @onChange={{setOne}} @value={{one.value}} />
          <DSelectTopic
            class="many"
            @multiple={{true}}
            @onChange={{setMany}}
            @value={{many.value}}
          />
        </template>
      );

      const single = new DSelect(".one");
      await single.open();
      await single.search("cats");
      await single.select(5);

      const multiple = new DSelect(".many");
      await multiple.open();
      await multiple.search("birds");
      await multiple.select(8);

      assert.deepEqual(changes, [
        ["one", 5, "Cats :smile:"],
        ["many", [3, 8], ["Dogs are great", "Closed birds"]],
      ]);
    });
  }
);

module(
  "Integration | ui-kit | select | recipes | DSelectTopicList",
  function (hooks) {
    setupRenderingTest(hooks);

    /** The list's search field. */
    function search(text) {
      return fillIn(".d-select.--list input[type='search']", text);
    }

    /** The listed option whose title includes `text`. */
    function optionNamed(text) {
      return findAll("[role='option']").find((row) =>
        row.textContent.includes(text)
      );
    }

    test("one held topic is replaced by a pick", async function (assert) {
      stubTopicSearch();
      stubTopicLookup();
      const held = tracked(3);
      const changes = [];
      const setHeld = (value, topic) => {
        changes.push([value, topic?.title]);
        held.value = value;
      };

      await render(
        <template>
          <DSelectTopicList
            @multiple={{false}}
            @onChange={{setHeld}}
            @value={{held.value}}
          />
        </template>
      );
      assert
        .dom(".d-select.--list")
        .hasAttribute("data-name", "Dogs are great", "the held topic is named");

      await search("cats");
      await click(optionNamed("Cats"));

      assert.deepEqual(changes, [[5, "Cats :smile:"]]);
      assert.dom(".d-select.--list").hasAttribute("data-value", "5");
    });

    test("shows nothing before a term", async function (assert) {
      const requests = stubTopicSearch();

      await render(<template><DSelectTopicList /></template>);

      assert.deepEqual(requests, [], "nothing is searched");
      assert
        .dom(".d-select__min-chars")
        .doesNotExist("no keep-typing hint: any term searches");
      assert.dom(".d-select__empty").doesNotExist("and no empty result");
    });

    test("leaves out the excluded topics", async function (assert) {
      stubTopicSearch();
      const exclude = [3];

      await render(
        <template><DSelectTopicList @exclude={{exclude}} /></template>
      );
      await search("e");

      assert.deepEqual(optionTitles(), ["Cats", "Closed birds"]);
    });

    test("additional filters list topics as it renders", async function (assert) {
      const requests = stubTopicSearch();
      const filters = "@sam in:created";

      await render(
        <template><DSelectTopicList @additionalFilters={{filters}} /></template>
      );

      assert.deepEqual(requests, [{ term: " @sam in:created" }]);
      assert.strictEqual(optionTitles().length, 3);
    });

    test("searches and is named for messages", async function (assert) {
      const requests = stubTopicSearch();

      await render(
        <template>
          <DSelectTopicList @archetype="private_message" @multiple={{false}} />
        </template>
      );
      await search("dogs");

      assert.strictEqual(requests[0].type_filter, "private_messages");
      assert
        .dom(".d-select.--list input[type='search']")
        .hasAria("label", "Message");
      assert
        .dom(".d-select.--list input[type='search']")
        .hasAttribute("placeholder", "Type a message title, URL or ID");
    });
  }
);
