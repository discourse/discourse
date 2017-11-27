import { acceptance } from 'helpers/qunit-helpers';
acceptance('Topic - Edit timer', { loggedIn: true });

QUnit.test('default', assert => {
  visit('/t/internationalization-localization');
  click('.toggle-admin-menu');
  click('.topic-admin-status-update button');

  andThen(() => {
    assert.equal(selectKit('.select-kit.timer-type').header.name(), 'Auto-Close Topic');
    assert.equal(selectKit('.future-date-input-selector').header.name(), 'Select a timeframe');
  });

  click('#private-topic-timer');

  andThen(() => {
    assert.equal(selectKit('.select-kit.timer-type').header.name(), 'Remind Me');
    assert.equal(selectKit('.future-date-input-selector').header.name(), 'Select a timeframe');
  });
});

QUnit.test('autoclose - specific time', assert => {
  visit('/t/internationalization-localization');
  click('.toggle-admin-menu');
  click('.topic-admin-status-update button');
  expandSelectKit('.future-date-input-selector');
  selectKitSelectRow('next_week', { selector: '.future-date-input-selector' });

  andThen(() => {
    assert.equal(selectKit('.future-date-input-selector').header.name(), 'Next week');
    const regex = /will automatically close in/g;
    const html = find('.future-date-input .topic-status-info').html().trim();
    assert.ok(regex.test(html));
  });
});

QUnit.test('autoclose', assert => {
  visit('/t/internationalization-localization');
  click('.toggle-admin-menu');
  click('.topic-admin-status-update button');
  expandSelectKit('.future-date-input-selector');

  selectKitSelectRow('next_week', { selector: '.future-date-input-selector' });
  andThen(() => {
    assert.equal(selectKit('.future-date-input-selector').header.name(), 'Next week');
    const regex = /will automatically close in/g;
    const html = find('.future-date-input .topic-status-info').html().trim();
    assert.ok(regex.test(html));
  });

  expandSelectKit('.future-date-input-selector');
  selectKitSelectRow('pick_date_and_time', { selector: '.future-date-input-selector' });
  fillIn('.future-date-input .date-picker', '2099-11-24');

  andThen(() => {
    assert.equal(selectKit('.future-date-input-selector').header.name(), 'Pick date and time');
    const regex = /will automatically close in/g;
    const html = find('.future-date-input .topic-status-info').html().trim();
    assert.ok(regex.test(html));
  });

  expandSelectKit('.future-date-input-selector');
  selectKitSelectRow('set_based_on_last_post', { selector: '.future-date-input-selector' });
  fillIn('.future-date-input input[type=number]', '2');
  andThen(() => {
    assert.equal(selectKit('.future-date-input-selector').header.name(), 'Close based on last post');
    const regex = /This topic will close.*after the last reply/g;
    const html = find('.future-date-input .topic-status-info').html().trim();
    assert.ok(regex.test(html));
  });
});

QUnit.test('close temporarily', assert => {
  visit('/t/internationalization-localization');
  click('.toggle-admin-menu');
  click('.topic-admin-status-update button');

  expandSelectKit('.select-kit.timer-type');
  selectKitSelectRow('open', { selector: '.select-kit.timer-type' });

  andThen(() => {
    assert.equal(selectKit('.future-date-input-selector').header.name(), 'Select a timeframe');
  });

  expandSelectKit('.future-date-input-selector');
  selectKitSelectRow('next_week', { selector: '.future-date-input-selector' });
  andThen(() => {
    assert.equal(selectKit('.future-date-input-selector').header.name(), 'Next week');
    const regex = /will automatically open in/g;
    const html = find('.future-date-input .topic-status-info').html().trim();
    assert.ok(regex.test(html));
  });

  expandSelectKit('.future-date-input-selector');
  selectKitSelectRow('pick_date_and_time', { selector: '.future-date-input-selector' });
  fillIn('.future-date-input .date-picker', '2099-11-24');

  andThen(() => {
    assert.equal(selectKit('.future-date-input-selector').header.name(), 'Pick date and time');
    const regex = /will automatically open in/g;
    const html = find('.future-date-input .topic-status-info').html().trim();
    assert.ok(regex.test(html));
  });
});

QUnit.test('schedule', assert => {
  visit('/t/internationalization-localization');
  click('.toggle-admin-menu');
  click('.topic-admin-status-update button');

  expandSelectKit('.select-kit.timer-type');
  selectKitSelectRow('publish_to_category', { selector: '.select-kit.timer-type' });

  andThen(() => {
    assert.equal(selectKit('.modal-body .category-chooser').header.name(), 'uncategorized');
    assert.equal(selectKit('.future-date-input-selector').header.name(), 'Select a timeframe');
  });

  expandSelectKit('.modal-body .category-chooser');
  selectKitSelectRow('7', { selector: '.modal-body .category-chooser' });

  expandSelectKit('.future-date-input-selector');
  selectKitSelectRow('next_week', { selector: '.future-date-input-selector' });

  andThen(() => {
    assert.equal(selectKit('.future-date-input-selector').header.name(), 'Next week');
    const regex = /will be published to #dev/g;
    const text = find('.future-date-input .topic-status-info').text().trim();
    assert.ok(regex.test(text));
  });
});

QUnit.test('auto delete', assert => {
  visit('/t/internationalization-localization');
  click('.toggle-admin-menu');
  click('.topic-admin-status-update button');

  expandSelectKit('.select-kit.timer-type');
  selectKitSelectRow('delete', { selector: '.select-kit.timer-type' });

  andThen(() => {
    assert.equal(selectKit('.future-date-input-selector').header.name(), 'Select a timeframe');
  });

  expandSelectKit('.future-date-input-selector');
  selectKitSelectRow('next_month', { selector: '.future-date-input-selector' });
  andThen(() => {
    assert.equal(selectKit('.future-date-input-selector').header.name(), 'Next month');
    const regex = /will be automatically deleted/g;
    const html = find('.future-date-input .topic-status-info').html().trim();
    assert.ok(regex.test(html));
  });
});
