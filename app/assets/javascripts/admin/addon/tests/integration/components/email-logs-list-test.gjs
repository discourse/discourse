import { fillIn, render, waitFor } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import EmailLogsList from "admin/components/email-logs-list";

const EMAIL_LOGS = [
  {
    id: 1,
    created_at: "2023-12-01T10:00:00Z",
    to_address: "test@example.com",
    cc_addresses: ["cc1@example.com", "cc2@example.com", "cc3@example.com"],
    email_type: "signup",
    smtp_transaction_response: "250 OK",
    reply_key: "abcdef123456",
    user: {
      id: 123,
      username: "testuser",
    },
    post_url: "/t/test-topic/1/2",
    post_description: "Test post",
    post_id: 2,
    bounced: false,
  },
  {
    id: 2,
    created_at: "2023-11-30T10:00:00Z",
    to_address: "user2@example.com",
    email_type: "digest",
    smtp_transaction_response: "250 OK",
    reply_key: "ghijk789012",
    user: {
      id: 456,
      username: "anotheruser",
    },
    bounced: true,
  },
];

module("Integration | Component | EmailLogsList", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    pretender.get("/admin/email-logs/sent.json", () => response(EMAIL_LOGS));
  });

  const mockHeaders = [
    { key: "admin.email.user" },
    { key: "admin.email.to_address" },
    { key: "admin.email.email_type" },
  ];

  const mockFilters = [
    {
      property: "filterUser",
      name: "user",
      placeholder: "admin.email.logs.filters.user_placeholder",
    },
    {
      property: "filterAddress",
      name: "address",
      placeholder: "admin.email.logs.filters.address_placeholder",
    },
  ];

  test("renders email log table", async function (assert) {
    await render(
      <template>
        <EmailLogsList
          @status="sent"
          @headers={{mockHeaders}}
          @filters={{mockFilters}}
        >
          <:default as |emailLog|>
            <tr>
              <td>{{emailLog.to_address}}</td>
            </tr>
          </:default>
        </EmailLogsList>
      </template>
    );

    assert.dom("table.email-list").exists("renders email list table");
    assert
      .dom("thead th")
      .exists({ count: 4 }, "renders headers + sent_at column");
    assert.dom("tr.filters").exists("renders filter row");
    assert
      .dom("tr.filters input")
      .exists({ count: 2 }, "renders filter inputs");
  });

  test("renders email log data", async function (assert) {
    await render(
      <template>
        <EmailLogsList
          @status="sent"
          @headers={{mockHeaders}}
          @filters={{mockFilters}}
        >
          <:default as |emailLog|>
            <tr class="test-row">
              <td class="test-address">{{emailLog.to_address}}</td>
              <td class="test-type">{{emailLog.email_type}}</td>
            </tr>
          </:default>
        </EmailLogsList>
      </template>
    );

    await waitFor(".test-row");

    assert.dom(".test-row").exists("renders yielded email log row");
    assert
      .dom(".test-address")
      .includesText("test@example.com", "yields email address");
    assert.dom(".test-type").includesText("signup", "yields email type");
  });

  test("filter inputs update component", async function (assert) {
    await render(
      <template>
        <EmailLogsList
          @status="sent"
          @headers={{mockHeaders}}
          @filters={{mockFilters}}
        >
          <:default>
            <tr><td>test</td></tr>
          </:default>
        </EmailLogsList>
      </template>
    );

    await waitFor("tr.filters input");

    assert.dom("tr.filters input").exists({ count: 2 }, "filter inputs exist");
  });

  test("filters actually filter the data", async function (assert) {
    let requestCount = 0;

    pretender.get("/admin/email-logs/sent.json", (request) => {
      requestCount++;

      const filteredData = [EMAIL_LOGS[0]];

      if (request.queryParams.address === "test@example.com") {
        assert.strictEqual(
          request.queryParams.address,
          "test@example.com",
          "value matches"
        );
        return response(filteredData);
      } else {
        return response(EMAIL_LOGS);
      }
    });

    await render(
      <template>
        <EmailLogsList
          @status="sent"
          @headers={{mockHeaders}}
          @filters={{mockFilters}}
        >
          <:default as |emailLog|>
            <tr class="email-row" data-id={{emailLog.id}}>
              <td class="email-address">{{emailLog.to_address}}</td>
            </tr>
          </:default>
        </EmailLogsList>
      </template>
    );

    await waitFor(".email-row");

    assert.dom(".email-row").exists({ count: 2 }, "initially shows all emails");

    const addressInput = "tr.filters td:nth-child(3) input";
    await fillIn(addressInput, "test@example.com");

    await waitFor(".email-row[data-id='1']");

    assert.strictEqual(requestCount, 2, "made a second request with filter");
    assert
      .dom(".email-row")
      .exists({ count: 1 }, "shows only one filtered email");
    assert
      .dom(".email-address")
      .hasText("test@example.com", "shows the correctly filtered email");

    await fillIn(addressInput, "");

    await waitFor(".email-row[data-id='2']");

    assert.strictEqual(
      requestCount,
      3,
      "made a third request when filter cleared"
    );
    assert
      .dom(".email-row")
      .exists({ count: 2 }, "shows all emails again after clearing filter");
  });
});
