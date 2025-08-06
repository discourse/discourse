## discourse-graphviz

https://meta.discourse.org/t/graphviz-plugin/97554/

Adds [Graphviz](https://www.graphviz.org) capability to discourse.

Topic discussing the plugin itself can be found here: https://meta.discourse.org/t/graphviz-plugin/97554

### Usage

See the [Graphviz](https://www.graphviz.org/documentation/) site for documentation and examples.  
To use with a discourse post, wrap the chart defintion in `graphviz` tags and define engine (if not defined, it will default to `dot`) like this:

```
[graphviz engine=neato]
graph {
  a -- b;
  b -- c;
  a -- c;
  d -- c;
  e -- c;
  e -- a;
}
[/graphviz]
```
