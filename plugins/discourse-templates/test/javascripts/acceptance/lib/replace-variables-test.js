import EmberObject from "@ember/object";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import {
  replaceVariables,
  TEMPLATES_ALLOWED_VARIABLES,
} from "discourse/plugins/discourse-templates/lib/replace-variables";
import extractVariablesFromChatChannel from "discourse/plugins/discourse-templates/lib/variables-chat-channel";
import extractVariablesFromComposerModel from "discourse/plugins/discourse-templates/lib/variables-composer";

acceptance(
  "Acceptance | Plugins | discourse-templates | Lib | replace-variables | models",
  function (needs) {
    needs.user({ username: "heisenberg", name: "Walter White", id: 1 });

    test("composer variables", function (assert) {
      const expectedVariables = {
        my_username: "heisenberg",
        my_name: "Walter White",
        topic_title: "Villains",
        topic_url: "/t/villains/6",
        context_title: "Villains",
        context_url: "/t/villains/6",
        original_poster_username: "mr_hide",
        original_poster_name: "Dr. Henry Jekyll",
        reply_to_username: "dracula",
        reply_to_name: "Vlad",
        last_poster_username: "frankenstein",
        reply_to_or_last_poster_username: "dracula",
      };

      const fakeModel = EmberObject.create({
        topic: {
          details: {
            created_by: {
              username: expectedVariables.original_poster_username,
              name: expectedVariables.original_poster_name,
            },
          },
          last_poster_username: expectedVariables.last_poster_username,
          title: "Villains",
          url: "/t/villains/6",
        },
        post: {
          username: expectedVariables.reply_to_username,
          name: expectedVariables.reply_to_name,
        },
      });

      for (const key of TEMPLATES_ALLOWED_VARIABLES) {
        let template, expected, preparedTemplate;

        // simple replacement
        template = {
          title: `test title:%{${key}}`,
          content: `test response:%{${key}}, %{${key}}, %{${key}}`,
        };
        expected = {
          title: `test title:${expectedVariables[key] || ""}`,
          content: `test response:${expectedVariables[key] || ""}, ${
            expectedVariables[key] || ""
          }, ${expectedVariables[key] || ""}`,
        };

        const templateVariables = extractVariablesFromComposerModel(fakeModel);

        preparedTemplate = replaceVariables(
          template.title,
          template.content,
          templateVariables
        );
        assert.strictEqual(
          preparedTemplate.title,
          expected.title,
          `%{${key}} simple replacement/title`
        );
        assert.strictEqual(
          preparedTemplate.content,
          expected.content,
          `%{${key}} simple replacement/content`
        );

        // replacement with fallback (variables defined)
        if (templateVariables[key]) {
          template = {
            title: `test title:%{${key},fallback:${key.toUpperCase()}}`,
            content: `test response:%{${key},fallback:${key.toUpperCase()}}, %{${key},fallback:${key.toUpperCase()}}, %{${key},fallback:${key.toUpperCase()}}`,
          };

          preparedTemplate = replaceVariables(
            template.title,
            template.content,
            templateVariables
          );
          assert.strictEqual(
            preparedTemplate.title,
            expected.title,
            `%{${key}} replacement with fallback - variable defined/title`
          );
          assert.strictEqual(
            preparedTemplate.content,
            expected.content,
            `%{${key}} replacement with fallback - variable defined/content`
          );
        }
      }
    });

    test("chat variables", function (assert) {
      const router = this.container.lookup("service:router");

      const expectedVariables = {
        my_username: "heisenberg",
        my_name: "Walter White",
        chat_channel_name: "Villains",
        chat_channel_url: "/chat/c/villains/6",
        context_title: "Villains",
        context_url: "/chat/c/villains/6",
        reply_to_username: "dracula",
        reply_to_name: "Vlad",
      };

      const fakeChannelModel = EmberObject.create({
        title: "Villains",
        routeModels: ["villains", 6],
        lastMessage: {
          user: {
            username: expectedVariables.last_poster_username,
          },
        },
      });

      const fakeMessageModel = EmberObject.create({
        inReplyTo: {
          user: {
            username: expectedVariables.reply_to_username,
            name: expectedVariables.reply_to_name,
          },
        },
      });

      for (const key of TEMPLATES_ALLOWED_VARIABLES) {
        let template, expected, preparedTemplate;

        // simple replacement
        template = {
          title: `test title:%{${key}}`,
          content: `test response:%{${key}}, %{${key}}, %{${key}}`,
        };
        expected = {
          title: `test title:${expectedVariables[key] || ""}`,
          content: `test response:${expectedVariables[key] || ""}, ${
            expectedVariables[key] || ""
          }, ${expectedVariables[key] || ""}`,
        };

        const templateVariables = extractVariablesFromChatChannel(
          fakeChannelModel,
          fakeMessageModel,
          router
        );

        preparedTemplate = replaceVariables(
          template.title,
          template.content,
          templateVariables
        );
        assert.strictEqual(
          preparedTemplate.title,
          expected.title,
          `%{${key}} simple replacement/title`
        );
        assert.strictEqual(
          preparedTemplate.content,
          expected.content,
          `%{${key}} simple replacement/content`
        );

        // replacement with fallback (variables defined)
        if (templateVariables[key]) {
          template = {
            title: `test title:%{${key},fallback:${key.toUpperCase()}}`,
            content: `test response:%{${key},fallback:${key.toUpperCase()}}, %{${key},fallback:${key.toUpperCase()}}, %{${key},fallback:${key.toUpperCase()}}`,
          };

          preparedTemplate = replaceVariables(
            template.title,
            template.content,
            templateVariables
          );
          assert.strictEqual(
            preparedTemplate.title,
            expected.title,
            `%{${key}} replacement with fallback - variable defined/title`
          );
          assert.strictEqual(
            preparedTemplate.content,
            expected.content,
            `%{${key}} replacement with fallback - variable defined/content`
          );
        }
      }
    });
  }
);

acceptance(
  "Acceptance | Plugins | discourse-templates | Lib | replace-variables | model undefined",
  function () {
    test("all variables", function (assert) {
      const router = this.container.lookup("service:router");

      for (const key of TEMPLATES_ALLOWED_VARIABLES) {
        let template, expected, preparedTemplate;

        // simple replacement
        template = {
          title: `test title:%{${key}}`,
          content: `test response:%{${key}}, %{${key}}, %{${key}}`,
        };
        expected = {
          title: `test title:`,
          content: `test response:, , `,
        };

        const templateVariables = extractVariablesFromChatChannel(
          null,
          null,
          router
        );

        preparedTemplate = replaceVariables(
          template.title,
          template.content,
          templateVariables
        );
        assert.strictEqual(
          preparedTemplate.title,
          expected.title,
          `%{${key}} simple replacement/title`
        );
        assert.strictEqual(
          preparedTemplate.content,
          expected.content,
          `%{${key}} simple replacement/content`
        );

        // replacement with fallback (variables undefined)
        template = {
          title: `test title:%{${key},fallback:${key.toUpperCase()}}`,
          content: `test response:%{${key},fallback:${key.toUpperCase()}}, %{${key},fallback:${key.toUpperCase()}}, %{${key},fallback:${key.toUpperCase()}}`,
        };
        expected = {
          title: `test title:${key.toUpperCase()}`,
          content: `test response:${key.toUpperCase()}, ${key.toUpperCase()}, ${key.toUpperCase()}`,
        };

        preparedTemplate = replaceVariables(
          template.title,
          template.content,
          {}
        );
        assert.strictEqual(
          preparedTemplate.title,
          expected.title,
          `%{${key}} replacement with fallback - variable undefined/title`
        );
        assert.strictEqual(
          preparedTemplate.content,
          expected.content,
          `%{${key}} replacement with fallback - variable undefined/content`
        );
      }
    });
  }
);
