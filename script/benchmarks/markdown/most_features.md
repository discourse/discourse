Based off https://markdown-it.github.io/ with every feature we support...


# h1 Heading 8-)
## h2 Heading
### h3 Heading
#### h4 Heading
##### h5 Heading
###### h6 Heading


## Horizontal Rules

___

---

***


## Emphasis

**This is bold text**

__This is bold text__

*This is italic text*

_This is italic text_

~~Strikethrough~~


## Blockquotes


> Blockquotes can also be nested...
>> ...by using additional greater-than signs right next to each other...
> > > ...or with spaces between arrows.


## Lists

Unordered

+ Create a list by starting a line with `+`, `-`, or `*`
+ Sub-lists are made by indenting 2 spaces:
  - Marker character change forces new list start:
    * Ac tristique libero volutpat at
    + Facilisis in pretium nisl aliquet
    - Nulla volutpat aliquam velit
+ Very easy!

Ordered

1. Lorem ipsum dolor sit amet
2. Consectetur adipiscing elit
3. Integer molestie lorem at massa


1. You can use sequential numbers...
1. ...or keep all the numbers as `1.`

Start numbering with offset:

57. foo
1. bar


## Code

Inline `code`

Indented code

    // Some comments
    line 1 of code
    line 2 of code
    line 3 of code


Block code "fences"

```
Sample text here...
```

Syntax highlighting

``` js
var foo = function (bar) {
  return bar++;
};

console.log(foo(5));
```


```text
var foo = function (bar) {
  return bar++;
};

console.log(foo(5));
```

## Tables

| Option | Description |
| ------ | ----------- |
| data   | path to data files to supply the data that will be passed into templates. |
| engine | engine to be used for processing templates. Handlebars is the default. |
| ext    | extension to be used for dest files. |

Right aligned columns

| Option | Description |
| ------:| -----------:|
| data   | path to data files to supply the data that will be passed into templates. |
| engine | engine to be used for processing templates. Handlebars is the default. |
| ext    | extension to be used for dest files. |


## Links

[link text](http://dev.nodeca.com)

[link with title](http://nodeca.github.io/pica/demo/ "title text!")

Autoconverted link https://github.com/discourse 


## Images

![Minion](/uploads/default/original/1X/f038dc6544a178b470b3014e92377b4dc996b991.png)
![](/uploads/default/original/1X/974402975b9ec316057a9e331bbade74d225bc46.jpg)

Like links, Images also have a footnote style syntax

![Alt text][id]

With a reference later in the document defining the URL location:

[id]: /uploads/default/original/1X/7bd599f0af2da1f370ea7b49ebec6e73c32d722b.jpg  "The Dojocat"


## Plugins

The killer feature of `markdown-it` is very effective support of
[syntax plugins](https://www.npmjs.org/browse/keyword/markdown-it-plugin).


### [Emojies](https://github.com/markdown-it/markdown-it-emoji)

> Classic markup: :wink:  :cry: :laughing: :yum: :surfing_woman:t4:   
>
> Shortcuts (emoticons) ;) :) 

see [how to change output](https://github.com/markdown-it/markdown-it-emoji#change-output) with twemoji.


### Polls

[poll type=number min=1 max=20 step=1 public=true]
[/poll]

[details=Summary]This is a spoiler[/details]


Multiline spoiler

[details=Summary]

This is a spoiler

[/details]


### Mentions
Mentions ... @sam 


### Categories

 #site-feedback

### Inline bbcode

Hello [code]I am code[/code] 



## A few paragraphs of **bacon**

Bacon ipsum dolor amet boudin ham hock burgdoggen, strip steak leberkas corned beef pork chop rump short loin porchetta shank venison andouille spare ribs turkey. Boudin tri-tip picanha chicken, porchetta beef ribs hamburger leberkas shankle flank pork spare ribs cupim biltong. Meatball pig leberkas sirloin beef tenderloin tongue picanha ham biltong ribeye chicken. Ham beef chuck frankfurter bresaola pig. Beef turkey ground round kevin pork belly doner jowl. Chicken burgdoggen shankle brisket short ribs capicola beef pancetta.

Rump t-bone beef ribs, cupim pork loin bresaola drumstick frankfurter capicola. Doner pastrami shank ribeye turkey ham hock meatloaf sirloin biltong pig ball tip beef ribs short loin shoulder. Meatball ribeye pastrami shank strip steak porchetta burgdoggen jowl short ribs sausage tail beef landjaeger capicola swine. Alcatra pork chop pork loin turkey, rump tenderloin landjaeger meatball swine ham hock strip steak sirloin. Strip steak drumstick tenderloin ground round, tongue ball tip t-bone tri-tip. Tenderloin doner boudin, sausage beef filet mignon short ribs.

Meatloaf pork loin pork belly porchetta landjaeger frankfurter fatback chicken. Short loin boudin bacon pastrami ball tip. Chicken burgdoggen bresaola chuck porchetta. Swine spare ribs cupim, shoulder rump boudin shank pork belly porchetta chicken pancetta beef meatloaf. Prosciutto shoulder hamburger, pig corned beef picanha filet mignon shankle t-bone jowl rump. Tri-tip pork burgdoggen flank salami short loin cow fatback pig ball tip kielbasa venison ham hock.

Flank jowl pastrami beef swine pork loin. Tail strip steak leberkas t-bone sausage, bresaola rump pastrami meatloaf short ribs prosciutto bacon cupim cow. Beef ribs shoulder ham hock beef meatloaf. Doner sausage porchetta, tongue pork chop jerky boudin meatball shoulder hamburger ribeye beef ribs. Pastrami turkey flank tri-tip, sausage ball tip rump ground round shankle.
