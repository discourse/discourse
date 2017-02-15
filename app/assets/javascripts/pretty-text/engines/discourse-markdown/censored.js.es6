import { censor } from 'pretty-text/censored-words';
import { registerOption } from 'pretty-text/pretty-text';

registerOption((siteSettings, opts) => {
  opts.features.censored = true;
  opts.censoredWords = siteSettings.censored_words;
  opts.censoredPattern = siteSettings.censored_pattern;
});

export function setup(helper) {
  helper.addPreProcessor(text => {
    const options = helper.getOptions();
    return censor(text, options.censoredWords, options.censoredPattern);
  });
}
