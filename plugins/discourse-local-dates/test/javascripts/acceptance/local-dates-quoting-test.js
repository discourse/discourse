import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import topicFixtures from "discourse/tests/fixtures/topic";
import { acceptance, selectText } from "discourse/tests/helpers/qunit-helpers";
import { cloneJSON } from "discourse-common/lib/object";

acceptance("Local Dates - quoting", function (needs) {
  needs.user();
  needs.settings({ discourse_local_dates_enabled: true });

  needs.pretender((server, helper) => {
    const topicResponse = cloneJSON(topicFixtures["/t/280/1.json"]);
    const firstPost = topicResponse.post_stream.posts[0];
    firstPost.cooked += `<div class='select-local-date-test'>This is a test <span data-date="2022-06-17" data-time="10:00:00" class="discourse-local-date cooked-date past" data-displayed-timezone="Australia/Perth" data-timezone="Australia/Brisbane" data-email-preview="2022-06-17T00:00:00Z UTC" aria-label="Brisbane Friday, June 17, 2022
	<br />
	<svg class='fa d-icon d-icon-clock svg-icon svg-string'
		xmlns=&quot;http://www.w3.org/2000/svg&quot;>
		<use href=&quot;#clock&quot; />
	</svg> 10:00 AM, Paris Friday, June 17, 2022
	<br />
	<svg class='fa d-icon d-icon-clock svg-icon svg-string'
		xmlns=&quot;http://www.w3.org/2000/svg&quot;>
		<use href=&quot;#clock&quot; />
	</svg> 2:00 AM, Los Angeles Thursday, June 16, 2022
	<br />
	<svg class='fa d-icon d-icon-clock svg-icon svg-string'
		xmlns=&quot;http://www.w3.org/2000/svg&quot;>
		<use href=&quot;#clock&quot; />
	</svg> 5:00 PM" data-title="This is a new topic to check on chat quote issues">
  <svg class="fa d-icon d-icon-earth-americas svg-icon" xmlns="http://www.w3.org/2000/svg">
    <use href="#earth-americas"></use>
  </svg>
  <span class="relative-time">June 17, 2022 8:00 AM (Perth)</span>
</span></div>`;

    server.get("/t/280.json", () => helper.response(topicResponse));
    server.get("/t/280/:post_number.json", () => {
      helper.response(topicResponse);
    });
  });

  test("quoting single local dates with basic options", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await selectText("#post_1 .select-local-date-test");
    await click(".insert-quote");
    assert.dom(".d-editor-input").hasValue(
      `[quote=\"uwe_keim, post:1, topic:280\"]
This is a test [date=2022-06-17 time=10:00:00 timezone="Australia/Brisbane" displayedTimezone="Australia/Perth"]
[/quote]\n\n`,
      "converts the date to markdown with all options correctly"
    );
  });
});

acceptance("Local Dates - quoting range", function (needs) {
  needs.user();
  needs.settings({ discourse_local_dates_enabled: true });

  needs.pretender((server, helper) => {
    const topicResponse = cloneJSON(topicFixtures["/t/280/1.json"]);
    const firstPost = topicResponse.post_stream.posts[0];
    firstPost.cooked += `<div class='select-local-date-test'><p dir="ltr">Some text <span data-date="2022-06-17" data-time="09:30:00" class="discourse-local-date cooked-date past" data-format="LL" data-range="true" data-timezones="Africa/Accra|Australia/Brisbane|Europe/Paris" data-timezone="Australia/Brisbane" data-email-preview="2022-06-16T23:30:00Z UTC" aria-label="Brisbane Friday, June 17, 2022 9:30 AM → Saturday, June 18, 2022 10:30 AM, Accra Thursday, June 16, 2022 11:30 PM → Saturday, June 18, 2022 12:30 AM, Paris Friday, June 17, 2022 1:30 AM → Saturday, June 18, 2022 2:30 AM" data-title="This is a new topic to check on chat quote issues">
        <svg class="fa d-icon d-icon-earth-americas svg-icon" xmlns="http://www.w3.org/2000/svg">
          <use href="#earth-americas"></use>
        </svg>
        <span class="relative-time">June 17, 2022</span>
      </span>→<span data-date="2022-06-18" data-time="10:30:00" class="discourse-local-date cooked-date past" data-format="LL" data-range="true" data-timezones="Africa/Accra|Australia/Brisbane|Europe/Paris" data-timezone="Australia/Brisbane" data-email-preview="2022-06-18T00:30:00Z UTC" aria-label="Brisbane Friday, June 17, 2022 9:30 AM → Saturday, June 18, 2022 10:30 AM, Accra Thursday, June 16, 2022 11:30 PM → Saturday, June 18, 2022 12:30 AM, Paris Friday, June 17, 2022 1:30 AM → Saturday, June 18, 2022 2:30 AM" data-title="This is a new topic to check on chat quote issues">
        <svg class="fa d-icon d-icon-earth-americas svg-icon" xmlns="http://www.w3.org/2000/svg">
          <use href="#earth-americas"></use>
        </svg>
        <span class="relative-time">June 18, 2022</span>
      </span></p></div>`;

    server.get("/t/280.json", () => helper.response(topicResponse));
    server.get("/t/280/:post_number.json", () => {
      helper.response(topicResponse);
    });
  });

  test("quoting a range of local dates", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await selectText("#post_1 .select-local-date-test");
    await click(".insert-quote");
    assert.dom(".d-editor-input").hasValue(
      `[quote=\"uwe_keim, post:1, topic:280\"]
Some text [date-range from=2022-06-17T09:30:00 to=2022-06-18T10:30:00 format="LL" timezone="Australia/Brisbane" timezones="Africa/Accra|Australia/Brisbane|Europe/Paris"]
[/quote]\n\n`,
      "converts the date range to markdown with all options correctly"
    );
  });
});

acceptance(
  "Local Dates - quoting with recurring and countdown",
  function (needs) {
    needs.user();
    needs.settings({ discourse_local_dates_enabled: true });

    needs.pretender((server, helper) => {
      const topicResponse = cloneJSON(topicFixtures["/t/280/1.json"]);
      const firstPost = topicResponse.post_stream.posts[0];
      firstPost.cooked += `<div class='select-local-date-test'><p dir="ltr">Testing countdown <span data-date="2022-06-21" data-time="09:30:00" class="discourse-local-date cooked-date" data-format="LL" data-countdown="true" data-timezone="Australia/Brisbane" data-email-preview="2022-06-20T23:30:00Z UTC" aria-label="Brisbane Tuesday, June 21, 2022 <br /><svg class='fa d-icon d-icon-clock svg-icon svg-string' xmlns=&quot;http://www.w3.org/2000/svg&quot;><use href=&quot;#clock&quot; /></svg> 9:30 AM, Paris Tuesday, June 21, 2022 <br /><svg class='fa d-icon d-icon-clock svg-icon svg-string' xmlns=&quot;http://www.w3.org/2000/svg&quot;><use href=&quot;#clock&quot; /></svg> 1:30 AM, Los Angeles Monday, June 20, 2022 <br /><svg class='fa d-icon d-icon-clock svg-icon svg-string' xmlns=&quot;http://www.w3.org/2000/svg&quot;><use href=&quot;#clock&quot; /></svg> 4:30 PM" data-title="This is a new topic to check on chat quote issues">
        <svg class="fa d-icon d-icon-earth-americas svg-icon" xmlns="http://www.w3.org/2000/svg">
          <use href="#earth-americas"></use>
        </svg>
        <span class="relative-time">21 hours</span>
      </span></p>
      <p dir="ltr">Testing recurring <span data-date="2022-06-22" class="discourse-local-date cooked-date" data-timezone="Australia/Brisbane" data-recurring="2.weeks" data-email-preview="2022-06-21T14:00:00Z UTC" aria-label="Brisbane Wednesday, June 22, 2022 12:00 AM → Thursday, June 23, 2022 12:00 AM, Paris Tuesday, June 21, 2022 4:00 PM → Wednesday, June 22, 2022 4:00 PM, Los Angeles Tuesday, June 21, 2022 7:00 AM → Wednesday, June 22, 2022 7:00 AM" data-title="This is a new topic to check on chat quote issues">
        <svg class="fa d-icon d-icon-earth-americas svg-icon" xmlns="http://www.w3.org/2000/svg">
          <use href="#earth-americas"></use>
        </svg>
        <span class="relative-time">Wednesday</span>
      </span></p></div>`;

      server.get("/t/280.json", () => helper.response(topicResponse));
      server.get("/t/280/:post_number.json", () => {
        helper.response(topicResponse);
      });
    });

    test("quoting single local dates with recurring and countdown options", async function (assert) {
      await visit("/t/internationalization-localization/280");
      await selectText("#post_1 .select-local-date-test");
      await click(".insert-quote");
      assert.dom(".d-editor-input").hasValue(
        `[quote=\"uwe_keim, post:1, topic:280\"]
Testing countdown [date=2022-06-21 time=09:30:00 format="LL" timezone="Australia/Brisbane" countdown="true"]

Testing recurring [date=2022-06-22 timezone="Australia/Brisbane" recurring="2.weeks"]
[/quote]\n\n`,
        "converts the dates to markdown with all options correctly"
      );
    });
  }
);
