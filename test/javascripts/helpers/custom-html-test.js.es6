import { blank } from 'helpers/qunit-helpers';
module("helper:custom-html");

import { getCustomHTML, setCustomHTML } from 'discourse/helpers/custom-html';

test("customHTML", function() {
  blank(getCustomHTML('evil'), "there is no custom HTML for a key by default");

  setCustomHTML('evil', 'trout');
  equal(getCustomHTML('evil'), 'trout', 'it retrieves the custom html');

  PreloadStore.store('customHTML', {cookie: 'monster'});
  equal(getCustomHTML('cookie'), 'monster', 'it returns HTML fragments from the PreloadStore');

});
