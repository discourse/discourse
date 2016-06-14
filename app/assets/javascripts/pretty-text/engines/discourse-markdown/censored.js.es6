import { censor } from 'pretty-text/censored-words';
import { registerOption } from 'pretty-text/pretty-text';

registerOption((siteSettings, opts) => {
  opts.features.censored = true;
  opts.censoredWords = siteSettings.censored_words;
});

export function setup(helper) {
  helper.addPreProcessor(text => {
    return censor(text, helper.getOptions().censoredWords);
  });
}
