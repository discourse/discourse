# closure wrapping means this does not leak into global context
validNavNames = ['read','popular','categories', 'favorited', 'category', 'unread', 'new', 'posted']
validAnon = ['popular', 'category', 'categories']

window.Discourse.NavItem = Em.Object.extend

  categoryName: (->
    split = @get('name').split('/')
    if (split[0] == 'category')
      split[1]
    else
      null
  ).property()

  href: (->
    # href from this item
    name = @get('name')
    if name == 'category'
      "/#{name}/#{@get('categoryName')}"
    else
      "/#{name}"
  ).property()

Discourse.NavItem.reopenClass
  # create a nav item from the text, will return null if there is not valid nav item for this particular text
  fromText: (text, opts) ->
    countSummary = opts["countSummary"]
    loggedOn = opts["loggedOn"]
    hasCategories = opts["hasCategories"]
    
    split = text.split(",")
    name = split[0]

    testName = name.split("/")[0] # to handle category ... 

    return null if !loggedOn && !validAnon.contains(testName)
    return null if !hasCategories && testName == "categories"
    return null unless validNavNames.contains(testName)

    opts =
      name: name
      hasIcon: name == "unread" || name == "favorited"
      filters: split.splice(1)

    if countSummary
      opts["count"] = countSummary[name] if countSummary && countSummary[name]

    Discourse.NavItem.create opts

