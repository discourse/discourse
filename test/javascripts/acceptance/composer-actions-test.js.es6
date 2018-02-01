import { acceptance } from 'helpers/qunit-helpers';

acceptance('Composer Actions', {
  loggedIn: true,
  settings: {
    enable_whispers: true
  }
});

QUnit.test('replying to post', assert => {
  const composerActions = selectKit('.composer-actions');

  visit('/t/internationalization-localization/280');
  click('article#post_3 button.reply');

  composerActions.expand();

  andThen(() => {
    assert.equal(composerActions.rowByIndex(0).value(), 'reply_as_new_topic');
    assert.equal(composerActions.rowByIndex(1).value(), 'reply_as_private_message');
    assert.equal(composerActions.rowByIndex(2).value(), 'reply_to_topic');
    assert.equal(composerActions.rowByIndex(3).value(), 'reply_as_whisper');
  });
});

QUnit.test('replying to post - reply_as_private_message', assert => {
  const composerActions = selectKit('.composer-actions');

  visit('/t/internationalization-localization/280');
  click('article#post_3 button.reply');

  composerActions.expand().selectRowByValue('reply_as_private_message');

  andThen(() => {
    assert.equal(find('.users-input .item:eq(0)').text(), 'codinghorror');
    assert.ok(find('.d-editor-input').val().indexOf('Continuing the discussion') >= 0);
  });
});

QUnit.test('replying to post - reply_to_topic', assert => {
  const composerActions = selectKit('.composer-actions');

  visit('/t/internationalization-localization/280');
  click('article#post_3 button.reply');
  fillIn('.d-editor-input', 'test replying to topic when intially replied to post');
  composerActions.expand().selectRowByValue('reply_to_topic');

  andThen(() => {
    assert.equal(find('.topic-post:last .cooked p').html().trim(), 'test replying to topic when intially replied to post');
    assert.notOk(exists(find('.topic-post:last .reply-to-tab')));
  });
});

QUnit.test('replying to post - reply_as_whisper', assert => {
  const composerActions = selectKit('.composer-actions');

  visit('/t/internationalization-localization/280');
  click('article#post_3 button.reply');
  fillIn('.d-editor-input', 'test replying as whisper to topic when intially not a whisper');
  composerActions.expand().selectRowByValue('reply_as_whisper');

  andThen(() => {
    assert.ok(exists(find('.topic-post:last .post-info.whisper')));
    assert.equal(find('.topic-post:last .cooked p').html().trim(), 'test replying as whisper to topic when intially not a whisper');
  });
});

QUnit.test('replying to post - reply_as_not_whisper', assert => {
  const composerActions = selectKit('.composer-actions');

  visit('/t/internationalization-localization/280');
  click('article#post_3 button.reply');
  fillIn('.d-editor-input', 'test replying as not a whisper to topic when intially a whisper');
  selectKit('.toolbar-popup-menu-options').expand().selectRowByValue('toggleWhisper');
  composerActions.expand().selectRowByValue('reply_as_not_whisper');

  andThen(() => {
    assert.notOk(exists(find('.topic-post:last .post-info.whisper')));
    assert.equal(find('.topic-post:last .cooked p').html().trim(), 'test replying as not a whisper to topic when intially a whisper');
  });
});

QUnit.test('replying to post - reply_as_new_topic', assert => {
  const composerActions = selectKit('.composer-actions');
  const categoryChooser = selectKit('.title-wrapper .category-chooser');
  const categoryChooserReplyArea = selectKit('.reply-area .category-chooser');

  visit('/t/internationalization-localization/280');

  click('#topic-title .d-icon-pencil');
  categoryChooser.expand().selectRowByValue(4);
  click('#topic-title .submit-edit');

  click('article#post_3 button.reply');
  composerActions.expand().selectRowByValue('reply_as_new_topic');

  andThen(() => {
    assert.equal(categoryChooserReplyArea.header().name(), 'faq');
    assert.ok(find('.d-editor-input').val().indexOf('Continuing the discussion') >= 0);
  });
});
