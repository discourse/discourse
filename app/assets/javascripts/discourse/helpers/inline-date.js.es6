import { relativeAge } from 'discourse/lib/formatter';

export default function(dt, params) {
  dt = params.data.view.getStream(dt).value();
  return relativeAge(new Date(dt));
}
