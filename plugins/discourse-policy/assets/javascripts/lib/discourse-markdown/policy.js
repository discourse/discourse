const rule = {
  tag: "policy",

  wrap(token, info) {
    if (!info.attrs.group && !info.attrs.groups) {
      return false;
    }

    token.attrs = [["class", "policy"]];

    // defaults to version 1 of the policy
    info.attrs.version ||= 1;

    for (let key of Object.keys(info.attrs).sort()) {
      token.attrs.push([`data-${key}`, info.attrs[key]]);
    }

    return true;
  },
};

export function setup(helper) {
  helper.allowList(["div.policy"]);

  helper.registerOptions((opts, siteSettings) => {
    opts.features.policy = !!siteSettings.policy_enabled;
  });

  helper.registerPlugin((md) => {
    md.block.bbcode.ruler.push("policy", rule);
  });
}
