import { cookAsync } from 'discourse/lib/text';
import guid from 'pretty-text/guid';
import { registerUnbound } from 'discourse-common/lib/helpers';

function cookText(text) {
  const id = `${guid().replace(/-/g, '')}`;

  cookAsync(text)
    .then(cooked => {
      Em.run.next(()=>{
        $('#' + id).html(cooked.string);
      });
  });

  return new Handlebars.SafeString(`<div id='${id}'></div>`);
}

registerUnbound('cook-text', cookText);
