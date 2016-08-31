import { cook } from 'discourse/lib/text';
import { registerUnbound } from 'discourse-common/lib/helpers';

registerUnbound('cook-text', cook);
