function all-classes($node) => ($node.attr(\class) ? '').split ' '

var $sidedivinner
export function postAceInit(hook_name, {ace})
  $sidedivinner := $ 'iframe[name="ace_outer"]' .contents!find '#sidedivinner'
    .addClass \authorColors
  ace.callWithAce (ace) ->
    $doc = $ ace.ace_getDocument!
    $body = $doc.find \body
    $body .get 0 .ownerDocument
      ..addEventListener \focus (->
        $sidedivinner.addClass \authorColors
        $body.addClass \focus), true
      ..addEventListener \blur (->
        $sidedivinner.removeClass \authorColors
        $body.removeClass \focus), true

function derive-primary-author($node)
  by-author = {}
  $node.find 'span' .each ->
    $this = $ this
    for spanclass in all-classes $this when spanclass is /^author/
      by-author[spanclass] ?= 0
      by-author[spanclass] += $this.text!length
  # mPA = most prolific author
  mPA = 0
  authorClass = null
  for author, value of by-author
    if value > mPA
      mPA = value
      authorClass = author
  return authorClass

function toggle-author($node, prefix, authorClass)
  has-class = false
  my-class = "#prefix-#authorClass"
  for c in all-classes $node when c.indexOf(prefix) is 0
    if c is my-class
      has-class = true
    else
      $node.removeClass c
  return false if has-class
  $node.addClass my-class
  return true

# here we mark primary author on magicdom divs as class
function update-domline($node)
  lineNumber = $node.index! + 1
  return false unless lineNumber

  authorClass = if $node.text!length > 0
    derive-primary-author $node
  else
    "none"

  toggle-author $node, "primary", authorClass

  author-view-update $node, lineNumber, null, authorClass

function extract-author($node)
  [a for a in all-classes $node when a is /^primary-/]?0?replace /^primary-/ ''

# cache the magicdomid to the sidediv lines, and use that to see if the line is dirty
function author-view-update($node, lineNumber, prev-author, authorClass)
  $authorContainer = $sidedivinner.find "div:nth-child(#lineNumber)"
  authorClass ?= extract-author $node
  unless prev-author
    prev = $authorContainer
    while prev.=prev! and prev.length
      prev-author = extract-author prev
      break if prev-author isnt \none

  if prev-author is authorClass
    $authorContainer.addClass \concise
  else
    $authorContainer.removeClass \concise

  prev-id = $authorContainer.attr(\id)?replace /^ref-/, ''
  if prev-id is $node.attr \id
    authorChanged = toggle-author $authorContainer, "primary", authorClass
    return unless authorChanged
  else
    $authorContainer.attr \id, 'ref-' + $node.attr \id
    toggle-author $authorContainer, "primary", authorClass

  next = $node.next!
  if next.length
    logical-prev-author = if authorClass is \none => prev-author else authorClass
    authorViewUpdate next, lineNumber+1, logical-prev-author

# add a hover for line numbers
fadeColor = (colorCSS, fadeFrac) ->
  color = colorutils.css2triple colorCSS
  colorutils.triple2css colorutils.blend color, [1 1 1 ], fadeFrac

getAuthorClassName = (author) ->
  'author-' + author.replace /[^a-y0-9]/g, (c) ->
    if c is '.'
      '-'
    else
      'z' + c.charCodeAt(0) + 'z'


# XXX: this should be just injected with aceEditorCSS. investigate if we can inject outer
var init
function outerInit(outerDynamicCSS)
  outerDynamicCSS.selectorStyle '#sidedivinner > div.primary-author-none'
    ..border-left = 'solid 0px '
    ..padding-left = '4px'
  outerDynamicCSS.selectorStyle '#sidedivinner > div.concise::before'
    ..content = "' '"
  outerDynamicCSS.selectorStyle '#sidedivinner > div'
    ..font-size = '0px'
    ..padding-left = '12px'
  outerDynamicCSS.selectorStyle '#sidedivinner > div::before'
    ..font-size = '1rem'
    ..text-overflow = 'ellipsis'
    ..overflow = 'hidden'
  init := true

export function aceSetAuthorStyle(name, context)
  { dynamicCSS, outerDynamicCSS, parentDynamicCSS, info, author } = context
  outerInit outerDynamicCSS unless init

  authorSelector = ".authorColors span.#authorClass"
  if info
    return 1 unless color = info.bgcolor
    authorClass = getAuthorClassName author
    authorName = authorNameAndColorFromAuthorId author .name
    # author style
    dynamicCSS.selectorStyle ".authorColors.focus span.#authorClass"
      ..border-bottom = "2px dotted #color"
    parentDynamicCSS.selectorStyle authorSelector
      ..border-bottom = "2px dotted #color"
    # primary author override
    dynamicCSS.selectorStyle ".authorColors.focus .primary-#authorClass .#authorClass"
      ..border-bottom = '0px'
    # primary author style on left
    outerDynamicCSS.selectorStyle "\#sidedivinner.authorColors > div.primary-#authorClass"
      ..border-left = "solid 4px #{color}"
      ..padding-left = '8px'
    outerDynamicCSS.selectorStyle "\#sidedivinner > div.primary-#authorClass::before"
      ..content = "'#{ authorName }'"

  else
    dynamicCSS.removeSelectorStyle ".authorColors.focus span.#authorClass"
    parentDynamicCSS.removeSelectorStyle authorSelector
  1

authorNameAndColorFromAuthorId = (authorId) ->
  myAuthorId = pad.myUserInfo.userId
  # It could always be me..
  if myAuthorId is authorId
    return do
      name: window._('author.me')
      color: pad.myUserInfo.colorId
  # Not me, let's look up in the DOM
  authorObj = {}
  $ '#otheruserstable > tbody > tr' .each ->
    if authorId is ($ this).data 'authorid'
      $ this
        ..find '.usertdname' .each ->
          authorObj.name = $ this .text! || window._('author.unknown')
        ..find '.usertdswatch > div' .each ->
          authorObj.color = $ this .css 'background-color'
      authorObj
  # Else go historical
  if not authorObj or not authorObj.name
    authorObj = clientVars.collab_client_vars.historicalAuthorData[authorId]
  # Try to use historical data
  authorObj or do
    name: window._('author.unknown')
    color: '#fff'

authorLines = {}

# When the DOM is edited
export function acePostWriteDomLineHTML(hook_name, args, cb)
  # avoid pesky race conditions
  <- setTimeout _, 200ms
  update-domline $ args.node

# on an edit
export function aceEditEvent(hook_name, {callstack}:context, cb)
  return unless callstack.type is \setWraps
  $ 'iframe[name="ace_outer"]' .contents!
    # no need for padding when we use borders
    ..find '#sidediv' .css 'padding-left': '0px'
    # set max width to 180
    ..find '#sidedivinner' .css do
      'max-width': '180px'
      overflow: 'hidden'
    # set align
    ..find '#sidediv > table' .attr 'align', 'left'

# For those who need them (< IE 9), add support for CSS functions
isStyleFuncSupported = CSSStyleDeclaration::getPropertyValue?

if not isStyleFuncSupported
  CSSStyleDeclaration::getPropertyValue = (a) -> @getAttribute a
  CSSStyleDeclaration::setProperty = (styleName, value, priority) ->
    @setAttribute styleName, value
    priority = if typeof priority isnt 'undefined' then priority else ''
    if not (priority is '')
      rule = new RegExp (RegExp.escape styleName) + '\\s*:\\s*' + RegExp.escape value + '(\\s*;)?', 'gmi'
      @cssText = @cssText.replace rule, styleName + ': ' + value + ' !' + priority + ';'
  # Add priority manually
  CSSStyleDeclaration::removeProperty = (a) -> @removeAttribute a
  CSSStyleDeclaration::getPropertyPriority = (styleName) ->
    rule = new RegExp (RegExp.escape styleName) + '\\s*:\\s*[^\\s]*\\s*!important(\\s*;)?', 'gmi'
    if rule.test @cssText
      'important'
    else
      ''

# Escape regex chars with \
RegExp.escape = (text) -> text.replace /[-[\]{}()*+?.,\\^$|#\s]/g, '\\$&'
