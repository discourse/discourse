import appRouteMap from "discourse/routes/app-route-map";

class RouteTreeBuilder {
  constructor(siteProps = {}) {
    this.root = { name: "root", fullName: "", children: [], opts: {} };
    this.stack = [this.root];
    this.siteProps = siteProps;
  }

  route(name, opts, fn) {
    if (typeof opts === "function") {
      fn = opts;
      opts = {};
    } else {
      opts = opts || {};
    }

    const parent = this.stack[this.stack.length - 1];
    const fullName = parent.fullName ? `${parent.fullName}.${name}` : name;

    const node = { name, fullName, children: [], opts };
    parent.children.push(node);

    if (fn) {
      this.stack.push(node);
      fn.call(this);
      this.stack.pop();
    }
  }

  getSiteProp(prop) {
    return this.siteProps[prop] || [];
  }
}

function findNode(root, fullName) {
  if (root.fullName === fullName) return root;
  for (const child of root.children) {
    const hit = findNode(child, fullName);
    if (hit) return hit;
  }
  return null;
}

export function buildRouteTree(siteProps = {}) {
  const builder = new RouteTreeBuilder(siteProps);
  appRouteMap.call(builder);
  return builder;
}

export function getSiblings(builder, routeName) {
  const parts = routeName.split(".");
  if (parts.length === 1) {
    return builder.root.children
      .map((n) => n.fullName)
      .filter((n) => n !== routeName);
  }

  const parentName = parts.slice(0, -1).join(".");
  const parent = findNode(builder.root, parentName);
  if (!parent) return [];

  return parent.children.map((n) => n.fullName).filter((n) => n !== routeName);
}
