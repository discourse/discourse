import { tracked } from "@glimmer/tracking";
import { click, fillIn, find, findAll, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import SiteSettingTopic from "discourse/admin/components/site-settings/topic";
import ChooseMessage from "discourse/components/choose-message";
import ChooseTopic from "discourse/components/choose-topic";
import CreateInvite from "discourse/components/modal/create-invite";
import CreateInviteWithRoles from "discourse/components/modal/create-invite-with-roles";
import loadAccessibleName from "discourse/lib/load-accessible-name";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, {
  parsePostData,
  response,
} from "discourse/tests/helpers/create-pretender";
import { DSelect } from "discourse/tests/helpers/d-select-helper";
import { i18n } from "discourse-i18n";

const TOPICS = [
  { id: 3, title: "Dogs are great", fancy_title: "Dogs are great" },
  { id: 5, title: "Cats are fine", fancy_title: "Cats are fine" },
  { id: 8, title: "Birds are loud", fancy_title: "Birds are loud" },
];

/**
 * Answers topic search like the server: topics whose title has every word of the term, filters
 * such as `status:public` aside. Records every request's params.
 */
function stubTopicSearch() {
  const requests = [];
  pretender.get("/search/query", (request) => {
    requests.push(request.queryParams);
    const words = request.queryParams.term
      .toLowerCase()
      .split(/\s+/)
      .filter((word) => word && !word.includes(":") && !word.startsWith("@"));
    const found = TOPICS.filter((topic) =>
      words.every((word) => topic.title.toLowerCase().includes(word))
    );
    return response({
      topics: found,
      posts: found.map((topic) => ({ id: topic.id * 10, topic_id: topic.id })),
    });
  });
  return requests;
}

/** Answers the held-topic lookup by the ids it is sent. */
function stubTopicLookup() {
  const requests = [];
  pretender.get("/topics/lookup.json", (request) => {
    const ids = []
      .concat(request.queryParams.topic_ids ?? [])
      .map((id) => parseInt(id, 10));
    requests.push(ids);
    return response({ topics: TOPICS.filter((t) => ids.includes(t.id)) });
  });
  return requests;
}

/** The option whose text includes `text`. */
function optionNamed(text) {
  return findAll("[role='option']").find((row) =>
    row.textContent.includes(text)
  );
}

/** The titles of the listed options, in order. */
function optionTitles() {
  return findAll("[role='option'] .d-topic-option__title").map((title) =>
    title.textContent.trim()
  );
}

module(
  "Integration | ui-kit | select | recipes | topic call sites",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      this.siteSettings.enable_new_select_controls = true;
    });

    module("site setting", function () {
      test("names the held topic through one lookup and writes the picked id", async function (assert) {
        stubTopicSearch();
        const lookups = stubTopicLookup();
        const held = tracked(3);
        const writes = [];
        const write = (value) => {
          writes.push(value);
          held.value = value;
        };
        const accessibleName = await loadAccessibleName();

        await render(
          <template>
            <SiteSettingTopic
              @changeValueCallback={{write}}
              @label="Welcome topic"
              @value={{held.value}}
            />
          </template>
        );

        assert.deepEqual(lookups, [[3]], "the held topic is looked up");
        assert.dom(".d-select").hasAttribute("data-name", "Dogs are great");
        assert.strictEqual(
          accessibleName(find("[role='combobox']")),
          "Welcome topic"
        );

        const select = new DSelect();
        await select.open();
        await select.search("cats");
        await click(optionNamed("Cats"));
        await select.clear();

        assert.deepEqual(writes, [5, null]);
      });

      test("an unset setting holds no topic", async function (assert) {
        const lookups = stubTopicLookup();
        const write = () => {};

        await render(
          <template>
            <SiteSettingTopic @changeValueCallback={{write}} @value="" />
          </template>
        );

        assert.deepEqual(lookups, [], "nothing is looked up");
        assert
          .dom("[role='combobox']")
          .hasAttribute(
            "placeholder",
            "Type a topic title, URL or ID",
            "the field is empty"
          );
      });
    });

    module("create invite", function () {
      test("offers public topics before a search and sends the picked topic", async function (assert) {
        this.currentUser.set("admin", true);
        this.siteSettings.must_approve_users = false;
        const searches = stubTopicSearch();
        let data;
        pretender.post("/invites", (request) => {
          data = parsePostData(request.requestBody);
          return response({ id: 5, link: "http://example.com/invites/x" });
        });
        const model = {};
        const accessibleName = await loadAccessibleName();

        await render(
          <template>
            <CreateInvite @inline={{true}} @model={{model}} />
          </template>
        );
        await click(".edit-link-options");

        const field = ".form-kit__field[data-name='inviteToTopic']";
        assert.strictEqual(
          accessibleName(find(`${field} [role='combobox']`)),
          i18n("user.invited.invite.invite_to_topic")
        );

        const select = new DSelect(`${field} .d-select`);
        await select.open();
        assert.deepEqual(searches, [{ term: " status:public" }]);

        await click(optionNamed("Birds"));
        await click(".save-invite");

        assert.strictEqual(data.topic_id, "8");
      });
    });

    module("create invite with roles", function () {
      test("the arrival topic field uses the topic picker, named after its title", async function (assert) {
        this.currentUser.set("admin", true);
        this.siteSettings.must_approve_users = false;
        const searches = stubTopicSearch();
        const model = {};
        const accessibleName = await loadAccessibleName();

        await render(
          <template>
            <CreateInviteWithRoles @inline={{true}} @model={{model}} />
          </template>
        );
        await click(".advanced-mode-btn");

        const field = ".form-kit__field[data-name='inviteToTopic']";
        assert.strictEqual(
          accessibleName(find(`${field} [role='combobox']`)),
          i18n("user.invited.invite.invite_to_topic")
        );
        await new DSelect(`${field} .d-select`).open();
        assert.deepEqual(searches, [{ term: " status:public" }]);
      });
    });

    module("choose topic", function () {
      test("lists matches other than the current topic and hands the pick on", async function (assert) {
        stubTopicSearch();
        const selected = tracked(null);
        const picks = [];
        const choose = (topic) => {
          picks.push(topic);
          selected.value = topic?.id;
        };
        const accessibleName = await loadAccessibleName();

        await render(
          <template>
            <ChooseTopic
              @currentTopicId={{3}}
              @selectedTopicId={{selected.value}}
              @topicChangedCallback={{choose}}
            />
          </template>
        );
        const input = ".choose-topic .d-select.--list input[type='search']";
        assert.strictEqual(
          accessibleName(find(input)),
          i18n("choose_topic.title.search")
        );

        await fillIn(input, "are");
        assert.deepEqual(optionTitles(), ["Cats are fine", "Birds are loud"]);

        await click(optionNamed("Cats"));

        assert.deepEqual(
          picks.map((topic) => [topic.id, topic.title]),
          [[5, "Cats are fine"]]
        );
        assert
          .dom(".choose-topic .d-select.--list")
          .hasAttribute("data-value", "5");
      });

      test("lists filtered topics as it opens when asked", async function (assert) {
        const searches = stubTopicSearch();
        const choose = () => {};

        await render(
          <template>
            <ChooseTopic
              @additionalFilters="status:public"
              @label="user.feature_topic_on_profile.search_label"
              @loadOnInit={{true}}
              @topicChangedCallback={{choose}}
            />
          </template>
        );

        assert.deepEqual(searches, [{ term: " status:public" }]);
        assert.strictEqual(optionTitles().length, 3);
        assert
          .dom(".choose-topic label")
          .hasText(i18n("user.feature_topic_on_profile.search_label"));
      });

      test("keeps the legacy search with the new controls off", async function (assert) {
        this.siteSettings.enable_new_select_controls = false;
        const choose = () => {};

        await render(
          <template><ChooseTopic @topicChangedCallback={{choose}} /></template>
        );

        assert.dom("#choose-topic-title").exists();
        assert.dom(".d-select").doesNotExist();
      });
    });

    module("choose message", function () {
      test("searches messages and hands the pick on", async function (assert) {
        const searches = stubTopicSearch();
        const selected = tracked(null);
        const picks = [];
        const choose = (message) => {
          picks.push(message?.id);
          selected.value = message?.id;
        };

        await render(
          <template>
            <ChooseMessage
              @currentTopicId={{3}}
              @selectedTopicId={{selected.value}}
              @setSelectedTopicId={{choose}}
            />
          </template>
        );
        await fillIn(
          ".choose-message .d-select.--list input[type='search']",
          "birds"
        );
        await click(optionNamed("Birds"));

        assert.strictEqual(searches[0].type_filter, "private_messages");
        assert.strictEqual(
          searches[0].restrict_to_archetype,
          "private_message"
        );
        assert.deepEqual(picks, [8]);
      });
    });
  }
);
