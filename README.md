# RDFa 1.1 in XSLT 1.0

This is a (burgeoning) implementation of [RDFa
1.1](https://www.w3.org/TR/rdfa-primer/) in [XSLT
1.0](https://www.w3.org/TR/xslt/).

# Rationale

> It's almost 2017: why are you doing *anything* in XSLT?

[I](http://doriantaylor.com/) have been using XSLT (1.0, to boot)
since sometime between late 2000 and early 2001. XSLT is:

* A DSL that concentrates on one thing: schlepping markup
* [An open standard](https://www.w3.org/TR/xslt/)
* With lightning-fast implementations (usually)
* Present in literally *every* Web browser [going back to MSIE
  5.0](https://en.wikipedia.org/wiki/Internet_Explorer_5#Overview),
  save for a few Android builds in between
* *Much* quicker to write for most needs than any DOM API or other
  imperative and/or object-oriented framework
* Consumes anything that can be incarnated as XML
* *Incapable* of producing XML markup that is not well-formed (unless
  you explicitly want to produce text that isn't XML)
* Results are therefore much easier to validate (note "well-formed"
  and "valid" are two different concepts in markup-land)
* Transformations for Web markup can be done on the command line, in a
  browser, in a filter on an origin server, or in a reverse proxy
* Inclusion functionality means code reuse *and* division of labour

## As General-Purpose Web Template Processor

From mid-2002 through 2005, I designed, implemented, and maintained a
workflow that enabled over a dozen translators to create fine-grained
internationalized content, *and* a room full of visual designers to
dress it up. For this task, we used [DocBook](http://docbook.org/) and
XSLT. I created, in effect, a library, with notches in it that the
visual designers could fill in with their changes to things like
navigation and chrome. They didn't need to know how anything worked,
just that they needed to sandwich their HTML in between a template
named this or that and they would get the results they wanted.

## As Lazy Man's CMS

I had an idea around 2007-2008, and I am somewhat embarrassed to admit
that I didn't have it sooner: *Use XSLT to turn (X)HTML into (X)HTML.*
Produce bare-bones markup on the server side containing *just the
content*, however you see fit, and then use XSLT to tack the ancillary
stuff on top in a separate process.

Better yet, use embedded metadata to signal resources which can
be [transcluded](https://en.wikipedia.org/wiki/Transclusion), along
with XSLT's
built-in [`document()`](https://www.w3.org/TR/xslt/#function-document)
function to haul them in. Use this method to recycle Atom/RSS feeds
(as I do on my own site) or generate [SVG](https://www.w3.org/TR/SVG/)
data visualizations (as I did on the client project which inspired me
to write this library).

I hereby reiterate that this technique can happen in the browser or
not, in a reverse proxy, in a filter on the origin server,
*completely* separate from the application, which thus can be any mix
of technical platforms, because they only have to produce well-formed
(X)HTML (and if they don't, you can get a filter for *that*, too).

> ...in a box, with a fox, in the rain, on a train, on a boat, with a
> goat...

## Embedded Metadata?

For my own site, and similar experiments, I simply piggybacked off
[the default terms](https://www.w3.org/1999/xhtml/vocab) you'd find in
`rel` attributes in `<link>` or `<a>` elements. If I was going to
develop the technique at all, I'd need something a lot more
sophisticated.

One of the biggest problems of metadata is defining what all the terms
mean. And then maintaining those definitions, making sure they get
used properly, resolving ambiguities and conflicts, collisions between
terms, etc. How, or even *if* you handle this is ultimately a
philosophical position. For me, the answer is
[RDF](https://www.w3.org/TR/rdf11-primer/), which I will hold distinct
from two other very closely-related concepts, [linked
data](http://linkeddata.org/) and the [Semantic
Web](https://www.w3.org/standards/semanticweb/).

> It is important to recognize that RDF is not a _syntax_,
> like [JSON](http://www.json.org/) is. RDF has _multiple_
> **equivalent**
> syntaxes, [*including* at least one in JSON](http://json-ld.org/).

RDF solves a number of problems with term management by making
everything a _URI_, which means the same term can live with two
different authorities and mean two different things. (It also means
some far-off PhD can spend years
developing
[an e-commerce vocabulary](http://www.heppnetz.de/ontologies/goodrelations/v1.html) so
I don't have to, with the bonus that if I *use* it, anybody else who
understands that vocabulary can automatically understand *my* data.)
By making those URIs dereferenceable **URLs**, you can put the
documentation for those terms, both human- and machine-readable, a
click or tap away, in an application of what we call _linked data_. On
top of *that* you can add all the eggheaded logic, inferencing, smart
agents and AI stuff, which is what we call the _Semantic Web_.

So what I see when I look at RDF is not just an overengineered
description framework for metadata terms aimed at a pipe dream, but a
natural and legitimate method for describing data *structures*, not
just for interchange but also for internal use, and therefore an
*extremely* practical way to organize the vagaries of everyday Web
development.

> You cannot tell me the JSON people don't have trouble managing
> things like the names of object keys, locations of API endpoints,
> etc yadda yadda.

## So What?

Stepping back to mid-2006, I was toying with the idea of creating an
RDF-based Web framework. The idea was that hitting a given URL would
disgorge a glob of data which was the _content_ of that URL, which
would contain, among other things, other URLs, connected via
well-understood attributes, which my (XSLT) templates would know to
convert into a link, or an image, or an embedded piece of text, or
whatever I wanted. This is a technique known as the impossibly-bad
acronym HATEOAS, which for those of you who actually
read
[Roy Fielding's dissertation](http://www.ics.uci.edu/~fielding/pubs/dissertation/top.htm),
know stands for _Hypertext as the Engine of Application State_, or a
really groovy way to make websites (if you can pull it off).

In 2006, RDFa wasn't invented yet, so I was using plain-Jane RDF/XML
syntax and trying to glean some structure from that. It turns out this
is a non-starter, because RDF/XML is just a bundle of statements, and
there is no acceptable way (to me at least) to signal which ones
belong to "the document" you just requested.

## Enter RDFa

In 2008, long after I backburner my aforementioned attempt, we get
RDFa. Initially, this is an extension to XHTML that enables RDF data
to be embedded into a document. Later on it becomes a generic set of
attributes which can be tacked on to HTML(5) or any XML vocabulary.

One interesting side effect of RDFa is that it solves the ambiguity
problem: Unless otherwise specified, embedded RDF statements are
assumed to be about the document in question. Or to straddle both RDF
and HTTP terminology, the subject is the Request-URI.

## What This Means

I'm looking to RDFa to create machine-readable data objects that
_also_ happen to be _human_-readable Web pages. Moreover, using
content-negotiation techniques, I can say something like "the resource
at the given URI *always* has the same meaning, irrespective of its
*syntax*, whether HTML, JSON, or RDF/XML."

This enables me to reorient my development targets in terms of
discrete resources, or _functions_ that _generate_ discrete resources,
and then those resources can be consumed downstream by literally
anything, _including_ my own applications. Then the site's user
interface can be considered _just another application_.

This XSLT library, therefore, makes it possible to implement the
application known as the given website's user interface.

# Programming Interface

## `rdfa:object-resources`

Given one or more subjects and a predicate, return the object
resources (URIs or blank nodes).

## `rdfa:subject-resources`

Same thing, but given an object resource (or bnode), return the
subject(s).

## `rdfa:object-literals`

**TODO** This one is actually going to be tricky because vanilla XSLT
1.0 can only return result sets or strings.

(I'm still not quite sure how this one is going to work yet but it's
almost certainly going to involve fishing the values out of a string.)

## `rdfa:object-literal-quick`

Given a subject and predicate (and optional language/datatype), and
assuming that you already know through some other mechanism that there
is only one statement to this effect, _and_ that the literal isn't an
XMLLiteral, return that literal.

(This is so you don't have to fish a single value out of a
weirdly-delimited string.)

## `rdfa:subjects-for-literal`

Given a literal (and optional language/datatype) and predicate, return
all associated subjects.

# Status/Road map

* [X] Proof of concept to establish whether the damn thing can be made
  to work at _all_,
* [X] Once it is made to work, try to make it reasonably fast,
* [ ] Sort out an interface which is amenable to the idiosyncrasies of XSLT,
    * [ ] Do something smart with lists and other collections
* [ ] Test cases!
* [ ] Documentation!

# Scope & Limitations

* This query engine is XSLT 1.0 (the only XSLT supported by Web
  browsers), processes only RDFa 1.1, and only (for now) (X)HTML.
    * Only `prefix` is supported. I didn't bother to implement the
      `xmlns` attribute fallback because of
      [a fifteen-year-old bug in Firefox](https://bugzilla.mozilla.org/show_bug.cgi?id=94270).
* XHTML input **must** have its `<base>` set to an absolute URI, and
  all relative URIs have to be relative to that address. It also helps
  if that address is the same as the Request-URI.
* This thing cannot handle arbitrary relative URIs. This is a
  necessary tradeoff for making the thing usably fast. It currently
  checks minimal relative URIs
  per [RFC 3986](https://tools.ietf.org/html/rfc3986) as well
  as [RFC 2396](https://tools.ietf.org/html/rfc2396), as well as
  absolute path/query/fragment. Arbitrary `./` and `../` components
  are no go.
* You are probably never going to see any kind of inferencing or
  reasoning with this thing, not without server-side help.
* Web browsers do not cross domains with XSLT (which is funny when you
  consider that you can do a lot more damage with JavaScript), so
  there's that too.

# Dependencies

This file relies (for now) on a handful of routines
from [XSLTSL](http://xsltsl.sourceforge.net/), which is a useful thing
in general.

# Copyright & License

Copyright 2016 Dorian Taylor

Licensed under the Apache License, Version 2.0 (the "License"); you
may not use this file except in compliance with the License. You may
obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
implied.  See the License for the specific language governing
permissions and limitations under the License.
