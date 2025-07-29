<?xml version="1.0" encoding="utf-8"?>
<xsl:stylesheet version="1.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:html="http://www.w3.org/1999/xhtml"
                xmlns:uri="http://xsltsl.org/uri"
                xmlns:str="http://xsltsl.org/string"
                xmlns:rdfa="http://www.w3.org/ns/rdfa#"
                xmlns:x="urn:x-dummy:"
                xmlns="http://www.w3.org/1999/xhtml"
                exclude-result-prefixes="html uri str rdfa x">

<!--
    Copyright 2016 Dorian Taylor

    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing,
    software distributed under the License is distributed on an "AS
    IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either
    express or implied. See the License for the specific language
    governing permissions and limitations under the License.
-->

<!--<xsl:import href="xsltsl/uri"/>-->
<!--<xsl:import href="xsltsl/string"/>-->

<!-- ### HERE IS A CRAPLOAD OF KEYS ### -->

<xsl:key name="rdfa:reverse-node-id" match="html:html|html:head|html:body|html:*[@about|@typeof|@resource|@href|@src|@rel|@rev|@property|@inlist]|html:*[@about|@typeof|@resource|@href|@src|@rel|@rev|@property|@inlist]/@*" use="generate-id(.)"/>

<xsl:key name="rdfa:has-typeof" match="html:*[@typeof]" use="''"/>

<!--<xsl:key name="rdfa:curie-node" match="html:*[@about][not(ancestor::*[@property and not(@content)])]/@about|html:*[@resource][not(ancestor::*[@property and not(@content)])]/@resource" use="normalize-space(.)"/>-->
<xsl:key name="rdfa:curie-node" match="html:*[@about][contains(@about, ':')]/@about|html:*[@resource][contains(@resource, ':')]/@resource" use="normalize-space(.)"/>

<!--<xsl:key name="rdfa:uri-node" match="html:*[@about][not(ancestor::*[@property and not(@content)])]/@about|html:*[@resource][not(ancestor::*[@property and not(@content)])]/@resource|html:*[@href][not(@resource)][not(ancestor::*[@property and not(@content)])]/@href|html:*[@src][not(@resource|@href)][not(ancestor::*[@property and not(@content)])]/@src" use="normalize-space(.)"/>-->
<xsl:key name="rdfa:uri-node" match="html:*[@about]/@about|html:*[@resource]/@resource|html:*[@href][not(@resource)]/@href|html:*[@src][not(@resource|@href)]/@src" use="normalize-space(.)"/>

<xsl:key name="rdfa:literal-content-node" match="html:*[@property][@content]" use="@content"/>
<xsl:key name="rdfa:literal-datetime-node" match="html:*[@property][@datetime]" use="@content"/>
<xsl:key name="rdfa:literal-text-node" match="html:*[@property][not(@content|@datetime)][@rel|@rev or not((@typeof and not(@about)) or @resource|@href|@src)]" use="string(.)"/>

<!-- umm is this what we want? -->
<xsl:key name="rdfa:rel-node" match="html:*[@rel][not(ancestor::*[@property and not(@content|@datetime)])]" use="''"/>
<xsl:key name="rdfa:rev-node" match="html:*[@rev][not(ancestor::*[@property and not(@content|@datetime)])]" use="''"/>

<!--
    we work it like this:

    key('rdfa:source-node', '[safe:curie]')|
    key('rdfa:source-node', 'bare:curie')|
    key('rdfa:source-node', $absolute-uri)|
    key('rdfa:source-node', $relative-uri)|
    key('rdfa:source-node', $absolute-path)

    * curie variants are only applicable if there is a prefix defined
    * absolute path/relative URI are only applicable for same domain
      ("authority" actually but whatever)

    relative URIs unfortunately come in a few styles, and that's not
    counting the literally infinite permutations of (dot-)dot-slash
    patterns:

    * if the base and reference are exactly the same
    * if the two are the same except for the fragment
    * if the two are the same except for the query

    one strategy is to begin with the last path segment no matter
    what. the other is to aggressively prune as much redundant data
    out of the relative reference as possible.

    note that the html+rdfa spec says that <head> and <body> are to be
    treated the same as the <html> (root) element in the rdfa 1.1 core
    spec.

-->
<xsl:variable name="uri:DEBUG"       select="false()"/>
<xsl:variable name="rdfa:DEBUG"      select="false()"/>
<xsl:variable name="rdfa:RECORD-SEP" select="'&#xf11e;'"/>
<xsl:variable name="rdfa:UNIT-SEP"   select="'&#xf11f;'"/>
<xsl:variable name="rdfa:RDF-NS"     select="'http://www.w3.org/1999/02/22-rdf-syntax-ns#'"/>
<xsl:variable name="rdfa:RDFS-NS"    select="'http://www.w3.org/2000/01/rdf-schema#'"/>
<xsl:variable name="rdfa:XSD-NS"     select="'http://www.w3.org/2001/XMLSchema#'"/>
<xsl:variable name="rdfa:RDF-TYPE"   select="concat($rdfa:RDF-NS, 'type')"/>

<x:doc>
  <h2>Templates cribbed from XSLTSL</h2>
</x:doc>

<x:doc>
  <h3>str:generate-string</h3>
</x:doc>

<xsl:template name="str:generate-string">
  <xsl:param name="text"/>
  <xsl:param name="count"/>
  <xsl:choose>
    <xsl:when test="string-length($text) = 0 or $count &lt;= 0"/>
    <xsl:otherwise>
      <xsl:value-of select="$text"/>
      <xsl:call-template name="str:generate-string">
        <xsl:with-param name="text" select="$text"/>
        <xsl:with-param name="count" select="$count - 1"/>
      </xsl:call-template>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<x:doc>
  <h3>str:subst</h3>
</x:doc>

<xsl:template name="str:subst">
  <xsl:param name="text"/>
  <xsl:param name="replace"/>
  <xsl:param name="with"/>
  <xsl:param name="disable-output-escaping">no</xsl:param>
  <xsl:choose>
    <xsl:when test="string-length($replace) = 0 and $disable-output-escaping = 'yes'">
      <xsl:value-of select="$text" disable-output-escaping="yes"/>
    </xsl:when>
    <xsl:when test="string-length($replace) = 0">
      <xsl:value-of select="$text"/>
    </xsl:when>
    <xsl:when test="contains($text, $replace)">
      <xsl:variable name="before" select="substring-before($text, $replace)"/>
      <xsl:variable name="after" select="substring-after($text, $replace)"/>
      <xsl:choose>
        <xsl:when test="$disable-output-escaping = 'yes'">
          <xsl:value-of select="$before" disable-output-escaping="yes"/>
          <xsl:value-of select="$with" disable-output-escaping="yes"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="$before"/>
          <xsl:value-of select="$with"/>
        </xsl:otherwise>
      </xsl:choose>
      <xsl:call-template name="str:subst">
        <xsl:with-param name="text" select="$after"/>
        <xsl:with-param name="replace" select="$replace"/>
        <xsl:with-param name="with" select="$with"/>
        <xsl:with-param name="disable-output-escaping" select="$disable-output-escaping"/>
      </xsl:call-template>
    </xsl:when>
    <xsl:when test="$disable-output-escaping = 'yes'">
      <xsl:value-of select="$text" disable-output-escaping="yes"/>
    </xsl:when>
    <xsl:otherwise><xsl:value-of select="$text"/></xsl:otherwise>
  </xsl:choose>
</xsl:template>

<x:doc>
  <h3>str:substring-before-last</h3>
</x:doc>

<xsl:template name="str:substring-before-last">
  <xsl:param name="text"/>
  <xsl:param name="chars"/>

  <xsl:choose>
    <xsl:when test="string-length($text) = 0"/>
    <xsl:when test="string-length($chars) = 0">
      <xsl:value-of select="$text"/>
    </xsl:when>
    <xsl:when test="contains($text, $chars)">
      <xsl:call-template name="str:substring-before-last-aux">
        <xsl:with-param name="text" select="$text"/>
        <xsl:with-param name="chars" select="$chars"/>
      </xsl:call-template>
    </xsl:when>
    <xsl:otherwise><xsl:value-of select="$text"/></xsl:otherwise>
  </xsl:choose>
</xsl:template>

<x:doc>
  <h3>str:substring-before-last-aux</h3>
  <p>this looks like a recursive bit</p>
</x:doc>

<xsl:template name="str:substring-before-last-aux">
  <xsl:param name="text"/>
  <xsl:param name="chars"/>

  <xsl:choose>
    <xsl:when test="string-length($text) = 0"/>
    <xsl:when test="contains($text, $chars)">
      <xsl:variable name="after">
        <xsl:call-template name="str:substring-before-last-aux">
          <xsl:with-param name="text" select="substring-after($text, $chars)"/>
          <xsl:with-param name="chars" select="$chars"/>
        </xsl:call-template>
      </xsl:variable>

      <xsl:value-of select="substring-before($text, $chars)"/>
      <xsl:if test="string-length($after) &gt; 0">
        <xsl:value-of select="$chars"/>
        <xsl:copy-of select="$after"/>
      </xsl:if>
    </xsl:when>
    <xsl:otherwise/>
  </xsl:choose>
</xsl:template>

<!--
    This is to split a list of tokens into roughly half using the
    limited repertoire available to XSLT 1.0. By "roughly" half we
    mean we're splitting based on the total length of the string. We
    want to do this because we're worried that just chopping off the
    first token in a list of tokens and recursing with the rest will
    blow the stack if the list is long enough; doing it this way will
    ensure the stack goes no deeper than log2(n) tokens. The XSLT
    stack is hard-coded on the order of 2000-5000, depending on the
    implementation.

    Step zero is apply `normalize-space()` so there is no leading or
    trailing whitespace and the only whitespace is non-consecutive
    actual (0x20) space characters.

    Now check if the string has any spaces. If not, return it.

    Now split the string naïvely in half. (How you decide to treat
    odd-length strings is not important.) If there is a space at the
    end of the first half or the beginning of the second half, we're
    done.

    Otherwise, one or both halves will contain at least one space.

    We can then take substring-before($right, ' ') and then measure
    the length of it, then check and see if a substring of that length
    on the *right* end of the *left* half contains a space. If it does
    (it could have more than one but we don't care), then it's a
    shorter distance from there to the exact middle of the original
    string.

    (ah shit no we'd still need to recurse on the left half if there
    were no spaces in the right half)

    (you could use substring-before if you knew there was only one
    space in the string)

    (you can count the spaces by doing translate($string, ' ', '') and
    subtracting the length of the translated string from the original;
    N spaces means N+1 tokens)

    okay so you cut the left half naively in half again and check the
    right half of the left half for spaces

    actually this is a distraction; will come back to it if needed
-->
<xsl:template name="str:tokens-roughly-half">
  <xsl:param name="tokens">
    <xsl:message terminate="yes">need some tokens bruh</xsl:message>
  </xsl:param>

  <xsl:variable name="norm" select="normalize-space($tokens)"/>

  <xsl:choose>
    <xsl:when test="contains($tokens, ' ')">
    </xsl:when>
    <xsl:otherwise>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<x:doc>
  <h3>uri:get-uri-scheme</h3>
</x:doc>

<xsl:template name="uri:get-uri-scheme">
  <xsl:param name="uri"/>

  <xsl:variable name="tf">
    <xsl:choose>
      <xsl:when test="contains($uri, '#')">
	<xsl:value-of select="substring-before($uri, '#')"/>
      </xsl:when>
      <xsl:otherwise><xsl:value-of select="$uri"/></xsl:otherwise>
    </xsl:choose>
  </xsl:variable>

  <xsl:variable name="tq">
    <xsl:choose>
      <xsl:when test="contains($tf, '?')">
	<xsl:value-of select="substring-before($tf, '?')"/>
      </xsl:when>
      <xsl:otherwise><xsl:value-of select="$tf"/></xsl:otherwise>
    </xsl:choose>
  </xsl:variable>

  <xsl:variable name="test">
    <xsl:choose>
      <xsl:when test="contains($tq, '/')">
	<xsl:value-of select="substring-before($tq, '/')"/>
      </xsl:when>
      <xsl:otherwise><xsl:value-of select="$tq"/></xsl:otherwise>
    </xsl:choose>
  </xsl:variable>

  <xsl:if test="contains($test, ':')">
    <xsl:value-of select="substring-before($test, ':')"/>
  </xsl:if>
</xsl:template>

<xsl:template name="uri:get-uri-authority">
  <xsl:param name="uri"/>

  <xsl:variable name="tf">
    <xsl:choose>
      <xsl:when test="contains($uri, '#')">
	<xsl:value-of select="substring-before($uri, '#')"/>
      </xsl:when>
      <xsl:otherwise><xsl:value-of select="$uri"/></xsl:otherwise>
    </xsl:choose>
  </xsl:variable>

  <xsl:variable name="test">
    <xsl:choose>
      <xsl:when test="contains($tf, '?')">
	<xsl:value-of select="substring-before($tf, '?')"/>
      </xsl:when>
      <xsl:otherwise><xsl:value-of select="$tf"/></xsl:otherwise>
    </xsl:choose>
  </xsl:variable>

  <xsl:variable name="scheme">
    <xsl:call-template name="uri:get-uri-scheme">
      <xsl:with-param name="uri" select="$test"/>
    </xsl:call-template>
  </xsl:variable>

  <!--<xsl:message>WAT <xsl:value-of select="$scheme"/></xsl:message>-->

  <xsl:variable name="a">
    <xsl:choose>
      <xsl:when test="string-length($scheme)">
	<xsl:variable name="after-scheme" select="substring($test, string-length($scheme) + 2)"/>
	<!--<xsl:message>after-scheme: <xsl:value-of select="$after-scheme"/></xsl:message>-->
        <xsl:if test="starts-with($after-scheme, '//')">
          <xsl:value-of select="substring($after-scheme, 3)"/>
        </xsl:if>
      </xsl:when>
      <xsl:otherwise>
        <xsl:if test="starts-with($test, '//')">
          <xsl:value-of select="substring($test, 3)"/>
        </xsl:if>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:variable>

  <xsl:choose>
    <xsl:when test="contains($a, '/')">
      <xsl:value-of select="substring-before($a, '/')" />
    </xsl:when>
    <xsl:when test="contains($a, '?')">
      <xsl:value-of select="substring-before($a, '?')" />
    </xsl:when>
    <xsl:when test="contains($a, '#')">
      <xsl:value-of select="substring-before($a, '#')" />
    </xsl:when>
    <xsl:otherwise>
      <xsl:value-of select="$a" />
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<x:doc>
  <h3>uri:get-uri-path</h3>
  <p>okay this falls down too</p>
  <p>how you should isolate the path is clip off the query and fragment <em>first</em> so you don't get false positives on colons</p>
</x:doc>

<xsl:template name="uri:get-uri-path">
  <xsl:param name="uri"/>

  <xsl:variable name="tf">
    <xsl:choose>
      <xsl:when test="contains($uri, '#')">
	<xsl:value-of select="substring-before($uri, '#')"/>
      </xsl:when>
      <xsl:otherwise><xsl:value-of select="$uri"/></xsl:otherwise>
    </xsl:choose>
  </xsl:variable>

  <xsl:variable name="test">
    <xsl:choose>
      <xsl:when test="contains($uri, '?')">
	<xsl:value-of select="substring-before($tf, '?')"/>
      </xsl:when>
      <xsl:otherwise><xsl:value-of select="$tf"/></xsl:otherwise>
    </xsl:choose>
  </xsl:variable>

  <xsl:choose>
    <xsl:when test="contains($test, '//')">
      <xsl:if test="contains(substring-after($test, '//'), '/')">
        <xsl:value-of select="concat('/', substring-after(substring-after($test, '//'), '/'))"/>
      </xsl:if>
    </xsl:when>
    <xsl:otherwise>
      <xsl:variable name="scheme">
	<xsl:call-template name="uri:get-uri-scheme">
	  <xsl:with-param name="uri" select="$test"/>
	</xsl:call-template>
      </xsl:variable>
      <xsl:choose>
        <xsl:when test="string-length($scheme)">
          <xsl:value-of select="substring($test, string-length($scheme) + 2)"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="$test"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:otherwise>
  </xsl:choose>

</xsl:template>

<x:doc>
  <h3>uri:get-uri-query</h3>
</x:doc>

<xsl:template name="uri:get-uri-query">
  <xsl:param name="uri"/>
  <xsl:variable name="q" select="substring-after($uri, '?')"/>
  <xsl:choose>
    <xsl:when test="contains($q, '#')">
      <xsl:value-of select="substring-before($q, '#')"/>
    </xsl:when>
    <xsl:otherwise><xsl:value-of select="$q"/></xsl:otherwise>
  </xsl:choose>
</xsl:template>

<x:doc>
  <h3>uri:get-uri-fragment</h3>
</x:doc>

<xsl:template name="uri:get-uri-fragment">
  <xsl:param name="uri"/>
  <xsl:value-of select="substring-after($uri, '#')"/>
</xsl:template>

<x:doc>
  <h3>uri:get-path-without-file</h3>
</x:doc>

<xsl:template name="uri:get-path-without-file">
  <xsl:param name="path-with-file" />
  <xsl:param name="path-without-file" />

  <xsl:choose>
    <xsl:when test="contains($path-with-file, '/')">
      <xsl:call-template name="uri:get-path-without-file">
        <xsl:with-param name="path-with-file" select="substring-after($path-with-file, '/')" />
        <xsl:with-param name="path-without-file">
          <xsl:choose>
            <xsl:when test="$path-without-file">
              <xsl:value-of select="concat($path-without-file, '/', substring-before($path-with-file, '/'))" />
            </xsl:when>
            <xsl:otherwise>
              <xsl:value-of select="substring-before($path-with-file, '/')" />
            </xsl:otherwise>
          </xsl:choose>
        </xsl:with-param>
      </xsl:call-template>
    </xsl:when>
    <xsl:otherwise>
      <xsl:value-of select="$path-without-file" />
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<x:doc>
  <h3>uri:normalize-path</h3>
</x:doc>

<xsl:template name="uri:normalize-path">
  <xsl:param name="path"/>
  <xsl:param name="result" select="''"/>

  <xsl:choose>
    <xsl:when test="string-length($path)">
      <xsl:choose>
        <xsl:when test="$path = '/'">
          <xsl:value-of select="concat($result, '/')"/>
        </xsl:when>
        <xsl:when test="$path = '.'">
          <xsl:value-of select="concat($result, '/')"/>
        </xsl:when>
        <xsl:when test="$path = '..'">
          <xsl:call-template name="uri:get-path-without-file">
            <xsl:with-param name="path-with-file" select="$result"/>
          </xsl:call-template>
          <xsl:value-of select="'/'"/>
        </xsl:when>
        <xsl:when test="contains($path, '/')">
          <!-- the current segment -->
          <xsl:variable name="s" select="substring-before($path, '/')"/>
          <!-- the remaining path -->
          <xsl:variable name="p">
            <xsl:choose>
              <xsl:when test="substring-after($path, '/') = ''">
                <xsl:value-of select="'/'"/>
              </xsl:when>
              <xsl:otherwise>
                <xsl:value-of select="substring-after($path, '/')"/>
              </xsl:otherwise>
            </xsl:choose>
          </xsl:variable>
          <xsl:choose>
            <xsl:when test="$s = ''">
              <xsl:call-template name="uri:normalize-path">
                <xsl:with-param name="path" select="$p"/>
                <xsl:with-param name="result" select="$result"/>
              </xsl:call-template>
            </xsl:when>
            <xsl:when test="$s = '.'">
              <xsl:call-template name="uri:normalize-path">
                <xsl:with-param name="path" select="$p"/>
                <xsl:with-param name="result" select="$result"/>
              </xsl:call-template>
            </xsl:when>
            <xsl:when test="$s = '..'">
              <xsl:choose>
                <xsl:when test="string-length($result) and (substring($result, string-length($result) - 2) != '/..')">
                  <xsl:call-template name="uri:normalize-path">
                    <xsl:with-param name="path" select="$p"/>
                    <xsl:with-param name="result">
                      <xsl:call-template name="uri:get-path-without-file">
                        <xsl:with-param name="path-with-file" select="$result"/>
                      </xsl:call-template>
                    </xsl:with-param>
                  </xsl:call-template>
                </xsl:when>
                <xsl:otherwise>
                  <xsl:call-template name="uri:normalize-path">
                    <xsl:with-param name="path" select="$p"/>
                    <xsl:with-param name="result" select="concat($result, '/..')"/>
                  </xsl:call-template>
                </xsl:otherwise>
              </xsl:choose>
            </xsl:when>
            <xsl:otherwise>
              <xsl:call-template name="uri:normalize-path">
                <xsl:with-param name="path" select="$p"/>
                <xsl:with-param name="result" select="concat($result, '/', $s)"/>
              </xsl:call-template>
            </xsl:otherwise>
          </xsl:choose>
        </xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="concat($result, '/', $path)"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:when>
    <xsl:otherwise>
      <xsl:value-of select="$result"/>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<x:doc>
  <h3>uri:document-for-uri</h3>
</x:doc>

<xsl:template name="uri:document-for-uri">
  <xsl:param name="uri">
    <xsl:message terminate="yes">`uri` parameter required</xsl:message>
  </xsl:param>
  <xsl:choose>
    <xsl:when test="contains($uri, '#')">
      <xsl:value-of select="normalize-space(substring-before($uri, '#'))"/>
    </xsl:when>
    <xsl:otherwise><xsl:value-of select="normalize-space($uri)"/></xsl:otherwise>
  </xsl:choose>
</xsl:template>

<!--
    ### THIS IS ALL STUFF THAT SHOULD REALLY BE INCORPORATED INTO XSLTSL ###
-->

<x:doc>
  <h3>uri:sanitize-path</h3>
</x:doc>

<xsl:template name="uri:sanitize-path">
  <xsl:param name="path" select="''"/>

  <xsl:variable name="clean-path">
    <xsl:choose>
      <xsl:when test="contains(normalize-space($path), ' ')">
        <xsl:call-template name="str:subst">
          <xsl:with-param name="text" select="normalize-space($path)"/>
          <xsl:with-param name="replace" select="' '"/>
          <xsl:with-param name="with" select="'%20'"/>
        </xsl:call-template>
      </xsl:when>
      <xsl:otherwise><xsl:value-of select="normalize-space($path)"/></xsl:otherwise>
    </xsl:choose>
  </xsl:variable>

  <xsl:if test="starts-with($clean-path, '/')"><xsl:text>/</xsl:text></xsl:if>
  <xsl:value-of select="translate(normalize-space(translate($clean-path, '/', ' ')), ' ', '/')"/>
  <xsl:if test="substring($clean-path, string-length($clean-path), 1) = '/'"><xsl:text>/</xsl:text></xsl:if>

</xsl:template>

<x:doc>
  <h3>uri:make-relative-path</h3>
</x:doc>

<xsl:template name="uri:make-relative-path">
  <xsl:param name="path" select="'/'"/>
  <xsl:param name="base" select="'/'"/>
  <xsl:param name="strict" select="false()"/>
  <xsl:param name="dotdot" select="0"/>

  <xsl:if test="not(starts-with($path, '/') and starts-with($base, '/'))">
    <xsl:message terminate="yes">uri:make-relative-path: both base and path must be absolute paths</xsl:message>
  </xsl:if>

  <xsl:choose>
    <xsl:when test="$dotdot = 0 and $strict and $path = $base">
      <xsl:value-of select="''"/>
    </xsl:when>
    <xsl:otherwise>
      <!-- give me up to and including the last slash -->
      <xsl:variable name="_b">
        <xsl:choose>
          <xsl:when test="substring($base, string-length($base), 1) = '/'">
            <xsl:value-of select="$base"/>
          </xsl:when>
          <xsl:otherwise>
            <xsl:call-template name="str:substring-before-last">
              <xsl:with-param name="text" select="$base"/>
              <xsl:with-param name="chars" select="'/'"/>
            </xsl:call-template>
            <xsl:text>/</xsl:text>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:variable>

      <!-- punt out the appropriate number of dotdots -->
      <xsl:call-template name="str:generate-string">
        <xsl:with-param name="text" select="'../'"/>
        <xsl:with-param name="count" select="$dotdot"/>
      </xsl:call-template>

      <xsl:choose>
        <!-- path is same as dirname of base -->
        <xsl:when test="$path != $base and $path = $_b and $dotdot = 0">
          <xsl:value-of select="'./'"/>
        </xsl:when>
        <!-- path begins with base -->
        <xsl:when test="starts-with($path, $_b)">
          <xsl:value-of select="substring-after($path, $_b)"/>
        </xsl:when>
        <!-- all other cases -->
        <xsl:otherwise>
          <xsl:call-template name="uri:make-relative-path">
            <xsl:with-param name="base">
              <xsl:call-template name="str:substring-before-last">
                <xsl:with-param name="text" select="substring($_b, 1, string-length($_b) - 1)"/>
                <xsl:with-param name="chars" select="'/'"/>
              </xsl:call-template>
              <xsl:text>/</xsl:text>
            </xsl:with-param>
            <xsl:with-param name="path" select="$path"/>
            <xsl:with-param name="strict" select="$strict"/>
            <xsl:with-param name="dotdot" select="$dotdot + 1"/>
          </xsl:call-template>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<x:doc>
  <h3>uri:resolve-uri</h3>
  <p>this is a temporary solution to deal with shortcomings in <code>uri:resolve-uri</code></p>
  <p>apparently one of them is to mess up urls with colons in them (a perfectly legal construct in the path/query/fragment)</p>
</x:doc>

<xsl:template name="uri:resolve-uri">
  <xsl:param name="uri"/>
  <xsl:param name="reference" select="$uri"/>
  <xsl:param name="base"/>
  <xsl:param name="document" select="$base"/>
  <xsl:param name="debug" select="$uri:DEBUG"/>

  <xsl:if test="$debug">
    <xsl:message>Resolving <xsl:value-of select="$reference"/></xsl:message>
  </xsl:if>

  <xsl:variable name="reference-scheme">
    <xsl:call-template name="uri:get-uri-scheme">
      <xsl:with-param name="uri" select="$reference"/>
    </xsl:call-template>
  </xsl:variable>

  <xsl:variable name="reference-authority">
    <xsl:call-template name="uri:get-uri-authority">
      <xsl:with-param name="uri" select="$reference"/>
    </xsl:call-template>
  </xsl:variable>

  <xsl:variable name="reference-path">
    <xsl:call-template name="uri:get-uri-path">
      <xsl:with-param name="uri" select="$reference"/>
    </xsl:call-template>
  </xsl:variable>

  <xsl:variable name="has-query" select="contains($reference, '?')"/>
  <xsl:variable name="reference-query">
    <xsl:call-template name="uri:get-uri-query">
      <xsl:with-param name="uri" select="$reference"/>
    </xsl:call-template>
  </xsl:variable>

  <xsl:variable name="has-fragment" select="contains($reference, '#')"/>
  <xsl:variable name="reference-fragment" select="substring-after($reference, '#')"/>

  <xsl:if test="$debug">
    <xsl:message>scheme: <xsl:value-of select="$reference-scheme"/> authority: <xsl:value-of select="$reference-authority"/> path: <xsl:value-of select="$reference-path"/> query: <xsl:value-of select="$reference-query"/> fragment: <xsl:value-of select="$reference-fragment"/></xsl:message>
  </xsl:if>

  <xsl:choose>
    <xsl:when test="string-length($reference-scheme)">
      <xsl:value-of select="$reference"/>
    </xsl:when>
    <xsl:when test="starts-with($reference, '?')">
      <xsl:choose>
        <xsl:when test="contains($document, '?')">
          <xsl:value-of select="substring-before($document, '?')"/>
        </xsl:when>
        <xsl:when test="contains($document, '#')">
          <xsl:value-of select="substring-before($document, '#')"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="$document"/>
        </xsl:otherwise>
      </xsl:choose>
      <xsl:value-of select="$reference"/>
    </xsl:when>
    <xsl:when test="not(string-length($reference-scheme)) and
                    not(string-length($reference-authority)) and
                    not(string-length($reference-path)) and not($has-query)">
      <xsl:choose>
        <xsl:when test="contains($document, '#')">
          <xsl:value-of select="substring-before($document, '#')"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="$document"/>
        </xsl:otherwise>
      </xsl:choose>

      <xsl:if test="$has-fragment">
        <xsl:value-of select="concat('#', $reference-fragment)"/>
      </xsl:if>
    </xsl:when>
    <xsl:otherwise>
      <xsl:variable name="base-scheme">
        <xsl:call-template name="uri:get-uri-scheme">
          <xsl:with-param name="uri" select="$base"/>
        </xsl:call-template>
      </xsl:variable>

      <xsl:variable name="base-authority">
        <xsl:call-template name="uri:get-uri-authority">
          <xsl:with-param name="uri" select="$base"/>
        </xsl:call-template>
      </xsl:variable>

      <xsl:variable name="base-path">
        <xsl:call-template name="uri:get-uri-path">
          <xsl:with-param name="uri" select="$base"/>
        </xsl:call-template>
      </xsl:variable>

      <xsl:variable name="base-query">
        <xsl:call-template name="uri:get-uri-query">
          <xsl:with-param name="uri" select="$base"/>
        </xsl:call-template>
      </xsl:variable>

      <xsl:variable name="base-fragment" select="substring-after($base, '#')"/>

      <xsl:variable name="result-authority">
        <xsl:choose>
          <xsl:when test="string-length($reference-authority)">
            <xsl:value-of select="$reference-authority"/>
          </xsl:when>
          <xsl:otherwise>
            <xsl:value-of select="$base-authority"/>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:variable>

      <xsl:variable name="result-path">
        <xsl:choose>
          <!-- don't normalize absolute paths -->
          <xsl:when test="starts-with($reference-path, '/')">
            <xsl:value-of select="$reference-path" />
          </xsl:when>
          <xsl:otherwise>
            <xsl:call-template name="uri:normalize-path">
              <xsl:with-param name="path">
                <xsl:if test="string-length($reference-authority) = 0 and substring($reference-path, 1, 1) != '/'">
                  <xsl:call-template name="uri:get-path-without-file">
                    <xsl:with-param name="path-with-file" select="$base-path"/>
                  </xsl:call-template>
                  <xsl:value-of select="'/'"/>
                </xsl:if>
                <xsl:value-of select="$reference-path"/>
              </xsl:with-param>
            </xsl:call-template>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:variable>

      <xsl:value-of select="concat($base-scheme, '://', $result-authority, $result-path)"/>

      <xsl:if test="$has-query">
        <xsl:value-of select="concat('?', $reference-query)"/>
      </xsl:if>

      <xsl:if test="$has-fragment">
        <xsl:value-of select="concat('#', $reference-fragment)"/>
      </xsl:if>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<x:doc>
  <h3>uri:make-absolute-uri</h3>
</x:doc>

<xsl:template name="uri:make-absolute-uri">
  <xsl:param name="uri"/>
  <xsl:param name="base"/>
  <xsl:param name="document" select="$base"/>

  <!-- resolve-uri removes empty query and fragment -->
  <xsl:variable name="has-query" select="contains($uri, '?')"/>
  <xsl:variable name="has-fragment" select="contains($uri, '#')"/>

  <!-- call the original resolver -->
  <xsl:variable name="out">
    <xsl:call-template name="uri:resolve-uri">
      <xsl:with-param name="reference" select="normalize-space($uri)"/>
      <xsl:with-param name="base" select="normalize-space($base)"/>
      <xsl:with-param name="document" select="$document"/>
    </xsl:call-template>
  </xsl:variable>

  <xsl:value-of select="$out"/>
  <xsl:if test="$has-query and not(contains($out, '?'))">
    <xsl:text>?</xsl:text>
  </xsl:if>
  <xsl:if test="$has-fragment and not(contains($out, '#'))">
    <xsl:text>#</xsl:text>
  </xsl:if>

</xsl:template>

<x:doc>
  <h3>uri:make-relative-uri</h3>
</x:doc>

<xsl:template name="uri:make-relative-uri">
  <xsl:param name="uri" select="''"/>
  <xsl:param name="base" select="''"/>
  <xsl:param name="strict" select="false()"/>
  <xsl:param name="debug" select="$uri:DEBUG"/>

  <xsl:variable name="abs-base" select="normalize-space($base)"/>
  <xsl:variable name="abs-uri">
    <xsl:call-template name="uri:resolve-uri">
      <xsl:with-param name="reference" select="normalize-space($uri)"/>
      <xsl:with-param name="base" select="$abs-base"/>
    </xsl:call-template>
  </xsl:variable>

  <!--<xsl:message>wtf yo <xsl:value-of select="$uri"/><xsl:text> </xsl:text><xsl:value-of select="$abs-uri"/></xsl:message>-->

  <xsl:choose>
    <!-- early exit for exact match -->
    <xsl:when test="$strict and $abs-uri = $abs-base"><xsl:value-of select="''"/></xsl:when>
    <xsl:otherwise>
      <!-- now match authority -->
      <xsl:variable name="uri-scheme">
        <xsl:call-template name="uri:get-uri-scheme">
          <xsl:with-param name="uri" select="$abs-uri"/>
        </xsl:call-template>
      </xsl:variable>

      <xsl:variable name="uri-authority">
        <xsl:call-template name="uri:get-uri-authority">
          <xsl:with-param name="uri" select="$abs-uri"/>
        </xsl:call-template>
      </xsl:variable>

      <xsl:variable name="scheme-authority" select="concat($uri-scheme, '://', $uri-authority, '/')"/>

      <xsl:choose>
        <xsl:when test="starts-with($abs-base, $scheme-authority)">
          <xsl:variable name="base-path">
            <xsl:call-template name="uri:get-uri-path">
              <xsl:with-param name="uri" select="$abs-base"/>
            </xsl:call-template>
          </xsl:variable>
          <xsl:variable name="uri-path">
            <xsl:call-template name="uri:get-uri-path">
              <xsl:with-param name="uri" select="$abs-uri"/>
            </xsl:call-template>
          </xsl:variable>
          <xsl:variable name="uri-has-query" select="contains($abs-uri, '?')"/>
          <xsl:variable name="uri-query">
            <xsl:call-template name="uri:get-uri-query">
              <xsl:with-param name="uri" select="$abs-uri"/>
            </xsl:call-template>
          </xsl:variable>
          <xsl:variable name="uri-has-fragment" select="contains($abs-uri, '#')"/>
          <xsl:variable name="uri-fragment">
            <xsl:call-template name="uri:get-uri-fragment">
              <xsl:with-param name="uri" select="$abs-uri"/>
            </xsl:call-template>
          </xsl:variable>

          <!-- path will either be empty or relative -->
          <xsl:variable name="result-path">
            <xsl:call-template name="uri:make-relative-path">
              <xsl:with-param name="base" select="$base-path"/>
              <xsl:with-param name="path" select="$uri-path"/>
              <xsl:with-param name="strict" select="$strict"/>
            </xsl:call-template>
          </xsl:variable>
          <xsl:value-of select="$result-path"/>

          <xsl:if test="$uri-has-query">
            <xsl:variable name="base-has-query" select="contains($abs-base, '?')"/>
            <xsl:variable name="base-query">
              <xsl:call-template name="uri:get-uri-query">
                <xsl:with-param name="uri" select="$abs-base"/>
              </xsl:call-template>
            </xsl:variable>
            <xsl:if test="not($strict and $result-path = '' and $base-has-query and $base-query = $uri-query)">
              <xsl:value-of select="concat('?', $uri-query)"/>
            </xsl:if>
          </xsl:if>

          <xsl:if test="$uri-has-fragment">
            <!--<xsl:message>has fragment yo</xsl:message>-->
            <xsl:variable name="base-has-fragment" select="contains($abs-base, '#')"/>
            <xsl:variable name="base-fragment">
              <xsl:call-template name="uri:get-uri-fragment">
                <xsl:with-param name="uri" select="$abs-base"/>
              </xsl:call-template>
            </xsl:variable>
            <xsl:if test="not($strict and $result-path = '' and $base-has-fragment and $base-fragment = $uri-fragment)">
              <xsl:value-of select="concat('#', $uri-fragment)"/>
            </xsl:if>
          </xsl:if>
        </xsl:when>
        <xsl:otherwise><xsl:value-of select="$abs-uri"/></xsl:otherwise>
      </xsl:choose>

    </xsl:otherwise>
  </xsl:choose>

</xsl:template>

<x:doc>
  <h3>uri:local-part</h3>
</x:doc>

<xsl:template name="uri:local-part">
  <xsl:param name="uri"/>
  <xsl:param name="base"/>

  <xsl:variable name="base-authority">
    <xsl:call-template name="uri:get-uri-authority">
      <xsl:with-param name="uri" select="$base"/>
    </xsl:call-template>
  </xsl:variable>
  <xsl:variable name="uri-authority">
    <xsl:call-template name="uri:get-uri-authority">
      <xsl:with-param name="uri" select="$uri"/>
    </xsl:call-template>
  </xsl:variable>

  <xsl:choose>
    <xsl:when test="$base-authority = $uri-authority">
      <xsl:value-of select="substring-after($uri, $uri-authority)"/>
    </xsl:when>
    <xsl:otherwise><xsl:value-of select="$uri"/></xsl:otherwise>
  </xsl:choose>

</xsl:template>

<x:doc>
  <h3>str:unique-tokens</h3>
  <p>deduplicate tokens</p>
</x:doc>

<xsl:template name="str:unique-tokens">
  <xsl:param name="string"/>
  <xsl:param name="tokens" select="$string"/>
  <xsl:param name="cache"/>

  <xsl:variable name="_norm" select="normalize-space($tokens)"/>

  <xsl:choose>
    <xsl:when test="$_norm  = ''">
      <xsl:value-of select="normalize-space($cache)"/>
    </xsl:when>
    <xsl:when test="contains($_norm, ' ')">
      <xsl:variable name="first" select="substring-before($_norm, ' ')"/>
      <xsl:variable name="rest"  select="substring-after($_norm, ' ')"/>

      <!-- cache always has a trailing space if not empty -->
      <xsl:variable name="cache-out">
        <xsl:choose>
        <xsl:when test="contains(concat(' ', $rest, ' '), concat(' ', $first, ' '))">
          <xsl:value-of select="$cache"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="concat($cache, $first, ' ')"/>
        </xsl:otherwise>
        </xsl:choose>
      </xsl:variable>

      <xsl:choose>
        <xsl:when test="contains($rest, ' ')">
          <xsl:call-template name="str:unique-tokens">
            <xsl:with-param name="tokens" select="$rest"/>
            <xsl:with-param name="cache"  select="$cache-out"/>
          </xsl:call-template>
        </xsl:when>
        <xsl:when test="contains(concat(' ', $cache-out, ' '), concat(' ' , $rest, ' '))">
          <xsl:value-of select="normalize-space($cache-out)"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="concat($cache-out, $rest)"/>
        </xsl:otherwise>
      </xsl:choose>

    </xsl:when>
    <xsl:otherwise>
      <xsl:value-of select="concat($cache, $_norm)"/>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<x:doc>
  <h3>str:unique-strings</h3>
</x:doc>

  <!--
      per https://www.w3.org/International/questions/qa-controls
      control codes are illegal in XML 1.0, even when escaped, which
      is too bad. in particular unit separator, record separator etc
      would be useful for dealing with literals.

      what we can do to compensate is use codepoints from the unicode
      private use area: map whitespace and separators to a set of
      codepoints.

      of course this will have the same weakness, namely that content
      may contain delimiters and then gum up the works, although
      potentially more likely with private-use unicode characters than
      control characters (e.g. custom emoji).

      nevertheless, the basic strategy here is to take the same octets
      we're interested in and plunk them somewhere in one of the
      private use areas (U+E000-U+F8FF etc), like so:

      0x1c -> &#xe01c; - file separator
      0x1d -> &#xe01d; - group separator
      0x1e -> &#xe01e; - record separator
      0x1f -> &#xe01f; - unit separator

      we will also need to do the same for whitespace characters, as
      literals can contain whitespace:

      0x09 -> &#xe009; - tab
      0x0a -> &#xe00a; - newline
      0x0d -> &#xe00d; - carriage return
      0x20 -> &#xe020; - space

      if we do this, we can do things like:

      1) encode the whitespace characters into their PUP counterparts
         with translate()
      2) translate() a particular delimiter into spaces and run
         normalize-space() to prune out empty records
      3) translate() the delimiter back to its original counterpart
      4) translate() whitespace chars back to their originals too

      NOTE actually we're using the range U+F100
  -->

<xsl:template name="str:unique-strings">
  <xsl:param name="string" select="''"/>
  <xsl:param name="delimiter" select="$rdfa:RECORD-SEP"/>

  <xsl:choose>
    <xsl:when test="contains($string, $delimiter)">
      <xsl:variable name="in" select="translate($string, '&#x09;&#x0a;&#x0d;&#x20;', '&#xf109;&#xf10a;&#xf10d;&#xf120;')"/>
      <xsl:variable name="out">
        <xsl:variable name="_">
          <xsl:call-template name="str:unique-tokens">
            <xsl:with-param name="string" select="translate($in, $delimiter, ' ')"/>
          </xsl:call-template>
        </xsl:variable>
        <xsl:value-of select="translate(normalize-space($_), ' ', $delimiter)"/>
      </xsl:variable>

      <xsl:value-of select="translate($out, '&#xf109;&#xf10a;&#xf10d;&#xf120;',  '&#x09;&#x0a;&#x0d;&#x20;')"/>
    </xsl:when>
    <xsl:otherwise><xsl:value-of select="$string"/></xsl:otherwise>
  </xsl:choose>

</xsl:template>

<x:doc>
  <h3>str:token-intersection</h3>
</x:doc>

<xsl:template name="str:token-intersection">
  <xsl:param name="left"  select="''"/>
  <xsl:param name="right" select="''"/>
  <xsl:param name="init"  select="true()"/>

  <xsl:variable name="_l" select="normalize-space($left)"/>
  <xsl:variable name="_r" select="normalize-space($right)"/>

  <!--<xsl:message>wtftoken <xsl:value-of select="string-length($_r)"/></xsl:message>-->


  <xsl:if test="string-length($_l) and string-length($_r)">
    <xsl:variable name="lfirst">
      <xsl:choose>
        <xsl:when test="contains($_l, ' ')">
          <xsl:value-of select="substring-before($_l, ' ')"/>
        </xsl:when>
        <xsl:otherwise><xsl:value-of select="$_l"/></xsl:otherwise>
      </xsl:choose>
    </xsl:variable>

    <xsl:if test="contains(concat(' ', $_r, ' '), concat(' ', $lfirst, ' '))">
      <!--<xsl:message><xsl:value-of select="$lfirst"/> in <xsl:value-of select="$_r"/></xsl:message>-->
      <xsl:value-of select="$lfirst"/>
    </xsl:if>

    <xsl:variable name="lrest" select="substring-after($_l, ' ')"/>

    <xsl:if test="string-length($lrest)">
      <xsl:text> </xsl:text>
      <xsl:call-template name="str:token-intersection">
        <xsl:with-param name="left"  select="$lrest"/>
        <xsl:with-param name="right" select="$_r"/>
        <xsl:with-param name="init"  select="false()"/>
      </xsl:call-template>
    </xsl:if>
  </xsl:if>
</xsl:template>

<!-- ### RDFA STUFF ### -->
<x:doc>
  <h2>RDFa Stuff</h2>
</x:doc>

<x:doc>
  <h3>rdfa:prefix-stack</h3>
</x:doc>

<xsl:template match="html:*" mode="rdfa:prefix-stack">
  <xsl:variable name="prefix">
    <xsl:for-each select="ancestor-or-self::html:*[@prefix]">
      <xsl:value-of select="concat(' ', @prefix)"/>
    </xsl:for-each>
  </xsl:variable>
  <xsl:value-of select="concat(' ', normalize-space($prefix), ' ')"/>
</xsl:template>


<x:doc>
  <h3>rdfa:resolve-curie</h3>
  <p>Resolve a CURIE.</p>
</x:doc>

<xsl:template name="rdfa:resolve-curie">
<xsl:param name="curie" select="''"/>
<xsl:param name="node" select="."/>
<xsl:param name="base"/>
<xsl:param name="prefixes">
  <xsl:apply-templates select="$node" mode="rdfa:prefix-stack"/>
</xsl:param>
<xsl:param name="resolve-terms" select="false()"/>

<xsl:variable name="content">
  <xsl:variable name="_nc" select="normalize-space($curie)"/>
  <xsl:variable name="_ncl" select="string-length($_nc)"/>
  <xsl:choose>
    <xsl:when test="starts-with($_nc, '[')">
      <xsl:choose>
        <xsl:when test="substring($_nc, $_ncl, 1) = ']'">
          <xsl:value-of select="normalize-space(substring($_nc, 2, $_ncl - 2))"/>
        </xsl:when>
        <xsl:otherwise><xsl:value-of select="substring-after($_nc, '[')"/></xsl:otherwise>
      </xsl:choose>
    </xsl:when>
    <xsl:otherwise><xsl:value-of select="$_nc"/></xsl:otherwise>
  </xsl:choose>
</xsl:variable>

<xsl:variable name="prefix" select="substring-before($content, ':')"/>

<xsl:choose>
  <xsl:when test="contains($content, '://')">
    <xsl:value-of select="$content"/>
  </xsl:when>
  <xsl:when test="contains($content, ':') and contains($prefixes, concat(' ', $prefix, ': '))">
    <xsl:variable name="slug" select="substring-after($content, ':')"/>
    <xsl:variable name="ns" select="substring-before(substring-after($prefixes, concat(' ', $prefix, ': ')), ' ')"/>
    <xsl:choose>
      <xsl:when test="string-length($ns) != 0">
        <xsl:value-of select="concat($ns, $slug)"/>
      </xsl:when>
      <xsl:otherwise><xsl:value-of select="$content"/></xsl:otherwise>
    </xsl:choose>
  </xsl:when>
  <xsl:when test="$resolve-terms and not(contains($content, ':')) and $node/ancestor-or-self::html:*[@vocab] and string-length($content) != 0">
    <xsl:variable name="v" select="normalize-space($node/ancestor-or-self::html:*[@vocab][1]/@vocab)"/>
    <xsl:value-of select="concat($v, $content)"/>
  </xsl:when>
  <xsl:otherwise>
    <xsl:call-template name="uri:make-absolute-uri">
      <xsl:with-param name="uri" select="$content"/>
      <xsl:with-param name="base" select="$base"/>
    </xsl:call-template>
  </xsl:otherwise>
</xsl:choose>

</xsl:template>

<x:doc>
  <h3>rdfa:resolve-curie-list</h3>
</x:doc>

<xsl:template name="rdfa:resolve-curie-list">
  <xsl:param name="list"/>
  <xsl:param name="node" select="."/>
  <xsl:param name="base"/>
  <xsl:param name="prefixes">
    <xsl:apply-templates select="$node" mode="rdfa:prefix-stack"/>
  </xsl:param>
  <xsl:param name="resolve-terms" select="false()"/>

  <xsl:variable name="str" select="normalize-space($list)"/>

  <xsl:if test="string-length($str) != 0">
    <xsl:variable name="first">
      <xsl:choose>
        <xsl:when test="contains($str, ' ')">
          <xsl:value-of select="substring-before($str, ' ')"/>
        </xsl:when>
        <xsl:otherwise><xsl:value-of select="$str"/></xsl:otherwise>
      </xsl:choose>
    </xsl:variable>

    <xsl:call-template name="rdfa:resolve-curie">
      <xsl:with-param name="curie" select="$first"/>
      <xsl:with-param name="node" select="$node"/>
      <xsl:with-param name="base" select="$base"/>
      <xsl:with-param name="prefixes" select="$prefixes"/>
      <xsl:with-param name="resolve-terms" select="$resolve-terms"/>
    </xsl:call-template>

    <xsl:variable name="rest" select="substring-after($str, ' ')"/>

    <xsl:choose>
      <xsl:when test="$rest = ''"/>
      <xsl:when test="contains($rest, ' ')">
        <xsl:text> </xsl:text>
        <xsl:call-template name="rdfa:resolve-curie-list">
          <xsl:with-param name="list" select="$rest"/>
          <xsl:with-param name="node" select="$node"/>
          <xsl:with-param name="base" select="$base"/>
          <xsl:with-param name="prefixes" select="$prefixes"/>
          <xsl:with-param name="resolve-terms" select="$resolve-terms"/>
        </xsl:call-template>
      </xsl:when>
      <xsl:otherwise>
        <xsl:text> </xsl:text>
        <xsl:call-template name="rdfa:resolve-curie">
          <xsl:with-param name="curie" select="$rest"/>
          <xsl:with-param name="node" select="$node"/>
          <xsl:with-param name="base" select="$base"/>
          <xsl:with-param name="prefixes" select="$prefixes"/>
          <xsl:with-param name="resolve-terms" select="$resolve-terms"/>
        </xsl:call-template>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:if>

</xsl:template>

<x:doc>
  <h3>rdfa:make-curie</h3>
</x:doc>

<xsl:template name="rdfa:make-curie">
  <xsl:param name="uri"/>
  <xsl:param name="node" select="."/>
  <xsl:param name="prefixes">
    <xsl:apply-templates select="$node" mode="rdfa:prefix-stack"/>
  </xsl:param>
  <xsl:param name="candidate" select="''"/>

  <xsl:variable name="has-prefixes" select="string-length(normalize-space($prefixes)) and contains(normalize-space($prefixes), ' ')"/>
  <xsl:variable name="has-candidate" select="string-length(normalize-space($candidate)) and contains(normalize-space($candidate), ' ')"/>

  <xsl:choose>
    <xsl:when test="$has-prefixes">
      <xsl:variable name="prefix" select="substring-before(normalize-space($prefixes), ' ')"/>
      <xsl:variable name="namespace">
        <xsl:variable name="_" select="substring-after(normalize-space($prefixes), ' ')"/>
        <xsl:choose>
          <xsl:when test="contains($_, ' ')">
            <xsl:value-of select="substring-before($_, ' ')"/>
          </xsl:when>
          <xsl:otherwise><xsl:value-of select="$_"/></xsl:otherwise>
        </xsl:choose>
      </xsl:variable>

      <xsl:if test="not(string-length($prefix) and substring($prefix, string-length($prefix), 1) = ':')">
        <xsl:message terminate="yes">got broken prefix <xsl:value-of select="$prefix"/></xsl:message>
      </xsl:if>

      <xsl:if test="not(string-length($namespace))">
        <xsl:message terminate="yes">got empty namespace</xsl:message>
      </xsl:if>

      <xsl:variable name="matches" select="starts-with($uri, $namespace)"/>

      <xsl:variable name="o-namespace">
        <xsl:variable name="_" select="substring-after($candidate, ' ')"/>
        <xsl:choose>
          <xsl:when test="$has-candidate and $matches and string-length($namespace) &gt; string-length($_)">
            <xsl:value-of select="$namespace"/>
          </xsl:when>
          <xsl:when test="$has-candidate"><xsl:value-of select="$_"/></xsl:when>
          <xsl:when test="$matches"><xsl:value-of select="$namespace"/></xsl:when>
          <xsl:otherwise/>
        </xsl:choose>
      </xsl:variable>

      <xsl:variable name="o-prefix">
        <xsl:variable name="_" select="substring-before($candidate, ' ')"/>
        <xsl:choose>
          <xsl:when test="$has-candidate and $matches and $o-namespace = $namespace">
            <xsl:value-of select="$prefix"/>
          </xsl:when>
          <xsl:when test="$has-candidate"><xsl:value-of select="$_"/></xsl:when>
          <xsl:when test="$matches"><xsl:value-of select="$prefix"/></xsl:when>
          <xsl:otherwise/>
        </xsl:choose>
      </xsl:variable>

      <!-- if there is a candidate we check -->
      <xsl:variable name="remaining" select="normalize-space(substring-after($prefixes, $namespace))"/>
      <xsl:choose>
        <xsl:when test="string-length($remaining)">
          <xsl:call-template name="rdfa:make-curie">
            <xsl:with-param name="uri" select="$uri"/>
            <xsl:with-param name="node" select="$node"/>
            <xsl:with-param name="prefixes" select="$remaining"/>
            <xsl:with-param name="candidate" select="normalize-space(concat($o-prefix, ' ', $o-namespace))"/>
          </xsl:call-template>
        </xsl:when>
        <xsl:when test="string-length($o-prefix) and string-length($o-namespace)">
          <xsl:value-of select="concat($o-prefix, substring-after($uri, $o-namespace))"/>
        </xsl:when>
        <xsl:otherwise/>
      </xsl:choose>
    </xsl:when>
    <xsl:when test="$has-candidate">
      <xsl:variable name="prefix" select="substring-before(normalize-space($candidate), ' ')"/>
      <xsl:variable name="namespace" select="substring-after(normalize-space($candidate), ' ')"/>

      <xsl:if test="not(string-length($prefix) and substring($prefix, string-length($prefix), 1) = ':')">
        <xsl:message terminate="yes">got broken prefix candidate <xsl:value-of select="$prefix"/></xsl:message>
      </xsl:if>

      <xsl:if test="not(starts-with($uri, $namespace))">
        <xsl:message terminate="yes">somehow got to processing a candidate with a non-matching namespace</xsl:message>
      </xsl:if>

      <xsl:value-of select="concat($prefix, substring-after($uri, $namespace))"/>
    </xsl:when>
    <xsl:otherwise/>
  </xsl:choose>

</xsl:template>

<x:doc>
  <h3>rdfa:make-curie-list</h3>
</x:doc>

<xsl:template name="rdfa:make-curie-list">
  <xsl:param name="list" select="''"/>
  <xsl:param name="node" select="."/>
  <xsl:param name="prefixes">
    <xsl:apply-templates select="$node" mode="rdfa:prefix-stack"/>
  </xsl:param>

  <xsl:variable name="nlist" select="normalize-space($list)"/>
  <xsl:variable name="first">
    <xsl:choose>
      <xsl:when test="contains($nlist, ' ')">
        <xsl:value-of select="substring-before($nlist, ' ')"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="$nlist"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:variable>

  <xsl:call-template name="rdfa:make-curie">
    <xsl:with-param name="uri" select="$first"/>
    <xsl:with-param name="node" select="$node"/>
    <xsl:with-param name="prefixes" select="$prefixes"/>
  </xsl:call-template>

  <xsl:if test="contains($nlist, ' ')">
    <xsl:text> </xsl:text>
    <xsl:call-template name="rdfa:make-curie-list">
      <xsl:with-param name="list" select="substring-after($nlist, ' ')"/>
      <xsl:with-param name="node" select="$node"/>
      <xsl:with-param name="prefixes" select="$prefixes"/>
    </xsl:call-template>
  </xsl:if>
</xsl:template>

<x:doc>
  <h3>rdfa:predicates-for-subject</h3>
  <p>Retrieve all the predicates for a given subject.</p>
</x:doc>

<xsl:template match="html:*" mode="rdfa:predicates-for-subject" name="rdfa:predicates-for-subject">
  <xsl:param name="subject" select="''"/>
  <xsl:param name="current" select="."/>
</xsl:template>

<x:doc>
  <h3>rdfa:predicates-for-resource-object</h3>
  <p>Retrieve all the predicates for a given object resource.</p>
</x:doc>

<xsl:template match="html:*" mode="rdfa:predicates-for-resource-object" name="rdfa:predicates-for-resource-object">
  <xsl:param name="subject" select="''"/>
  <xsl:param name="current" select="."/>
</xsl:template>

<x:doc>
  <h3>rdfa:predicates-for-literal-object</h3>
  <p>Retrieve all the predicates for a given literal.</p>
</x:doc>

<xsl:template match="html:*" mode="rdfa:predicates-for-literal-object" name="rdfa:predicates-for-literal-object">
  <xsl:param name="subject" select="''"/>
  <xsl:param name="current" select="."/>
</xsl:template>


<x:doc>
  <h3>rdfa:subjects-for-predicate</h3>
</x:doc>

<!--
    if subject is empty then only top of the tree or anything with
    about
-->

<xsl:template name="rdfa:subjects-for-predicate">
  <xsl:param name="predicate" select="''"/>
  <xsl:param name="current" select="."/>
</xsl:template>

<x:doc>
  <h3>rdfa:new-subject</h3>
</x:doc>

<!--
    ascending will probably look something like:

    self::*[@about|@typeof] and stop.
    ancestor::*[@about|@typeof|@resource|@href|@src][1]

    descending like:

    self::*[@resource|@href|@src] and stop.
    otherwise descendant::*[@about|@typeof|

-->

<xsl:template match="html:*[not(@rel|@rev)][@property][not(@content|@datetime|@datatype)]" mode="rdfa:new-subject">
  <xsl:param name="base" select="normalize-space((/html:html/html:head/html:base[@href])[1]/@href)"/>

  <xsl:choose>
    <xsl:when test="@about">
      <xsl:call-template name="rdfa:resolve-curie">
        <xsl:with-param name="curie" select="@about"/>
        <xsl:with-param name="base" select="$base"/>
      </xsl:call-template>
    </xsl:when>
    <xsl:when test="self::html:head|self::html:body">
      <xsl:apply-templates select="." mode="rdfa:parent-object">
        <xsl:with-param name="base" select="$base"/>
      </xsl:apply-templates>
    </xsl:when>
    <xsl:when test="self::html:html"><xsl:value-of select="$base"/></xsl:when>
    <xsl:otherwise>
      <xsl:apply-templates select="." mode="rdfa:parent-object">
        <xsl:with-param name="base" select="$base"/>
      </xsl:apply-templates>
      <!--<xsl:value-of select="concat('_:', generate-id())"/>-->
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<xsl:template match="html:*" mode="rdfa:new-subject">
  <xsl:param name="base" select="normalize-space((/html:html/html:head/html:base[@href])[1]/@href)"/>

  <xsl:choose>
    <xsl:when test="@about">
      <xsl:call-template name="rdfa:resolve-curie">
        <xsl:with-param name="curie" select="@about"/>
        <xsl:with-param name="base" select="$base"/>
      </xsl:call-template>
    </xsl:when>
    <xsl:when test="@resource">
      <xsl:call-template name="rdfa:resolve-curie">
        <xsl:with-param name="curie" select="@resource"/>
        <xsl:with-param name="base" select="$base"/>
      </xsl:call-template>
    </xsl:when>
    <xsl:when test="@href">
      <xsl:call-template name="uri:resolve-uri">
        <xsl:with-param name="uri" select="normalize-space(@href)"/>
        <xsl:with-param name="base" select="$base"/>
      </xsl:call-template>
    </xsl:when>
    <xsl:when test="@src">
      <xsl:call-template name="uri:resolve-uri">
        <xsl:with-param name="uri" select="normalize-space(@src)"/>
        <xsl:with-param name="base" select="$base"/>
      </xsl:call-template>
    </xsl:when>
    <xsl:when test="self::html:html"><xsl:value-of select="$base"/></xsl:when>
    <xsl:when test="self::html:head|self::html:body">
      <xsl:apply-templates select="." mode="rdfa:parent-object">
        <xsl:with-param name="base" select="$base"/>
      </xsl:apply-templates>
    </xsl:when>
    <xsl:when test="@typeof">
      <xsl:value-of select="concat('_:', generate-id(.))"/>
    </xsl:when>
    <xsl:otherwise>
      <xsl:apply-templates select="." mode="rdfa:parent-object">
        <xsl:with-param name="base" select="$base"/>
      </xsl:apply-templates>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<xsl:template match="html:*[@rel|@rev]" mode="rdfa:new-subject">
  <xsl:param name="base" select="normalize-space((/html:html/html:head/html:base[@href])[1]/@href)"/>

  <xsl:choose>
    <xsl:when test="@about">
      <xsl:call-template name="rdfa:resolve-curie">
        <xsl:with-param name="curie" select="@about"/>
        <xsl:with-param name="base" select="$base"/>
      </xsl:call-template>
    </xsl:when>
    <xsl:when test="self::html:html"><xsl:value-of select="$base"/></xsl:when>
    <xsl:when test="self::html:head|self::html:body">
      <xsl:apply-templates select="." mode="rdfa:parent-object">
        <xsl:with-param name="base" select="$base"/>
      </xsl:apply-templates>
    </xsl:when>
    <xsl:otherwise>
      <xsl:apply-templates select="." mode="rdfa:parent-object">
        <xsl:with-param name="base" select="$base"/>
      </xsl:apply-templates>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<x:doc>
  <h3>rdfa:current-object-resource</h3>
</x:doc>


<xsl:template match="html:*[not(@rel|@rev)][@property][not(@content|@datetime|@datatype)][@typeof]" mode="rdfa:current-object-resource">
  <xsl:param name="base" select="normalize-space((/html:html/html:head/html:base[@href])[1]/@href)"/>

  <xsl:choose>
    <xsl:when test="@about">
      <xsl:call-template name="rdfa:resolve-curie">
        <xsl:with-param name="curie" select="@about"/>
        <xsl:with-param name="base" select="$base"/>
      </xsl:call-template>
    </xsl:when>
    <xsl:when test="self::html:html"><xsl:value-of select="$base"/></xsl:when>
    <xsl:when test="self::html:head|self::html:body">
      <xsl:apply-templates select="." mode="rdfa:parent-object">
        <xsl:with-param name="base" select="$base"/>
      </xsl:apply-templates>
    </xsl:when>
    <xsl:when test="@resource">
      <xsl:call-template name="rdfa:resolve-curie">
        <xsl:with-param name="curie" select="@resource"/>
        <xsl:with-param name="base" select="$base"/>
      </xsl:call-template>
    </xsl:when>
    <xsl:when test="@href">
      <xsl:call-template name="uri:resolve-uri">
        <xsl:with-param name="uri" select="normalize-space(@href)"/>
        <xsl:with-param name="base" select="$base"/>
      </xsl:call-template>
    </xsl:when>
    <xsl:when test="@src">
      <xsl:call-template name="uri:resolve-uri">
        <xsl:with-param name="uri" select="normalize-space(@src)"/>
        <xsl:with-param name="base" select="$base"/>
      </xsl:call-template>
    </xsl:when>
  </xsl:choose>
</xsl:template>

<xsl:template match="html:*[@rel|@rev]" mode="rdfa:current-object-resource">
  <xsl:param name="base" select="normalize-space((/html:html/html:head/html:base[@href])[1]/@href)"/>

  <xsl:choose>
    <xsl:when test="@resource">
      <xsl:call-template name="rdfa:resolve-curie">
        <xsl:with-param name="curie" select="@resource"/>
        <xsl:with-param name="base" select="$base"/>
      </xsl:call-template>
    </xsl:when>
    <xsl:when test="@href">
      <xsl:call-template name="uri:resolve-uri">
        <xsl:with-param name="uri" select="normalize-space(@href)"/>
        <xsl:with-param name="base" select="$base"/>
      </xsl:call-template>
    </xsl:when>
    <xsl:when test="@src">
      <xsl:call-template name="uri:resolve-uri">
        <xsl:with-param name="uri" select="normalize-space(@src)"/>
        <xsl:with-param name="base" select="$base"/>
      </xsl:call-template>
    </xsl:when>
    <xsl:when test="@typeof and not(@about)">
      <xsl:value-of select="concat('_:', generate-id(.))"/>
    </xsl:when>
    <xsl:otherwise/>
  </xsl:choose>
</xsl:template>

<xsl:template match="html:*" mode="rdfa:current-object-resource"/>

<!--
<xsl:template match="html:*[not(@rel|@rev|@about|@typeof|@resource|@href|@src)][not(@property) or (@property and @content)]" mode="rdfa:parent-subject">
  <xsl:param name="base" select="normalize-space((/html:html/html:head/html:base[@href])[1]/@href)"/>
  <xsl:apply-templates select=".." mode="rdfa:parent-subject">
    <xsl:with-param name="base" select="$base"/>
  </xsl:apply-templates>
</xsl:template>
-->

<x:doc>
  <h3>rdfa:parent-subject</h3>
</x:doc>

<xsl:template match="html:*" mode="rdfa:parent-subject">
  <xsl:param name="base" select="normalize-space((/html:html/html:head/html:base[@href])[1]/@href)"/>

  <xsl:variable name="_">
    <xsl:apply-templates select=".." mode="rdfa:new-subject">
      <xsl:with-param name="base" select="$base"/>
    </xsl:apply-templates>
  </xsl:variable>

  <xsl:choose>
    <xsl:when test="string-length(normalize-space($_))">
      <xsl:value-of select="$_"/>
    </xsl:when>
    <xsl:otherwise>
      <xsl:apply-templates select="../.." mode="rdfa:new-subject">
        <xsl:with-param name="base" select="$base"/>
      </xsl:apply-templates>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<!--
<xsl:template match="html:*[not(@rel|@rev|@about|@typeof|@resource|@href|@src)][not(@property) or (@property and @content)]" mode="rdfa:parent-object">
  <xsl:param name="base" select="normalize-space((/html:html/html:head/html:base[@href])[1]/@href)"/>
  <xsl:apply-templates select=".." mode="rdfa:parent-object">
    <xsl:with-param name="base" select="$base"/>
  </xsl:apply-templates>
</xsl:template>
-->

<x:doc>
  <h3>rdfa:parent-object</h3>
</x:doc>

<xsl:template match="html:*" mode="rdfa:parent-object">
  <xsl:param name="base" select="normalize-space((/html:html/html:head/html:base[@href])[1]/@href)"/>

  <xsl:variable name="cor">
    <xsl:apply-templates select=".." mode="rdfa:current-object-resource">
      <xsl:with-param name="base" select="$base"/>
    </xsl:apply-templates>
  </xsl:variable>

  <xsl:choose>
    <xsl:when test="string-length($cor)"><xsl:value-of select="$cor"/></xsl:when>
    <xsl:otherwise>
      <xsl:variable name="ns">
        <xsl:apply-templates select=".." mode="rdfa:new-subject">
          <xsl:with-param name="base" select="$base"/>
        </xsl:apply-templates>
      </xsl:variable>
      <xsl:choose>
        <xsl:when test="string-length($ns)"><xsl:value-of select="$ns"/></xsl:when>
        <xsl:otherwise>
          <xsl:apply-templates select=".." mode="rdfa:parent-subject">
            <xsl:with-param name="base" select="$base"/>
          </xsl:apply-templates>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:otherwise>
  </xsl:choose>

</xsl:template>

<x:doc>
  <h3>rdfa:skip-element</h3>
</x:doc>

<xsl:template match="html:*" mode="rdfa:skip-element"/>
<xsl:template match="html:*[not(@rel|@rev|@about|@resource|@href|@src|@typeof|@property)]" mode="rdfa:skip-element">
<!-- will get stringified but alternative is empty ergo false so whatev -->
<xsl:value-of select="true()"/>
</xsl:template>

<x:doc>
  <h3>rdfa:is-subject</h3>
</x:doc>

<!-- we have an attribute or element, and we want to know if it is a
     subject or object -->
<xsl:template match="html:*|html:*/@*" mode="rdfa:is-subject"/>
<xsl:template match="html:*/@about|
                     html:*[not(@rel|@rev|@about)][not(@property) or (@property and @content|@datetime|@datatype)]/@resource|
                     html:*[not(@rel|@rev|@about|@resource)][not(@property) or (@property and @content|@datetime|@datatype)]/@href|
                     html:*[not(@rel|@rev|@about|@resource|@href)][not(@property) or (@property and @content|@datetime|@datatype)]/@src|
                     html:*[@typeof][not(@about|@rel|@rev)][not(@property) or (@property and @content|@datetime|@datatype)]|
                     html:body|html:head|html:html" mode="rdfa:is-subject">
  <xsl:value-of select="true()"/>
</xsl:template>

<x:doc>
  <h3>rdfa:my-typeof</h3>
</x:doc>

<xsl:template match="html:*|html:*/@*" mode="rdfa:my-typeof"/><!--
  <xsl:message>busted my-typeof: <xsl:apply-templates select="." mode="element-dump"/></xsl:message>
</xsl:template>-->
<xsl:template match="html:*[@typeof]/@about|
                     html:*[@typeof][not(@about)][@resource]/@resource|
                     html:*[@typeof][not(@about|@resource)][@href]/@href|
                     html:*[@typeof][not(@about|@resource|@href)][@src]/@src|
                     html:*[@typeof]" mode="rdfa:my-typeof">
  <xsl:param name="base" select="normalize-space((/html:html/html:head/html:base[@href])[1]/@href)"/>

  <xsl:variable name="element" select="(self::*|..)[last()]"/>

  <xsl:call-template name="rdfa:resolve-curie-list">
    <xsl:with-param name="list" select="$element/@typeof"/>
    <xsl:with-param name="node" select="$element"/>
    <xsl:with-param name="base" select="$base"/>
    <xsl:with-param name="resolve-terms" select="true()"/>
  </xsl:call-template>
</xsl:template>

<x:doc>
  <h3>rdfa:element-dump</h3>
</x:doc>

<xsl:template match="html:*|html:*/@*" mode="element-dump">
  <xsl:variable name="element" select="(self::*|..)[last()]"/>
  <xsl:text>&lt;</xsl:text><xsl:value-of select="name($element)"/>
  <xsl:for-each select="$element/@*">
    <xsl:value-of select="concat(' ', name(), '=&quot;', ., '&quot;')"/>
    </xsl:for-each><xsl:text>&gt;</xsl:text>
</xsl:template>

<!-- WHAT WE WERE ORIGINALLY WORKING ON -->

<x:doc>
  <h3>rdfa:resource-down</h3>
</x:doc>

<xsl:template match="*|@*" mode="rdfa:resource-down">
  <xsl:message terminate="yes">THIS rdfa:resource-down SHOULD NEVER GET RUN</xsl:message>
</xsl:template>

<xsl:template match="html:*[not(@rel|@rev|@about|@typeof|@resource|@href|@src)][(@property and @content|@datetime) or not(@property)]" mode="rdfa:resource-down">
  <xsl:param name="base" select="normalize-space((/html:html/html:head/html:base[@href])[1]/@href)"/>
  <xsl:param name="debug" select="$rdfa:DEBUG"/>

  <xsl:if test="debug">
    <xsl:message>RESOURCE DOWN PASSTHRU <xsl:apply-templates select="." mode="element-dump"/></xsl:message>
  </xsl:if>

  <xsl:apply-templates select="html:*" mode="rdfa:resource-down">
    <xsl:with-param name="base" select="$base"/>
    <xsl:with-param name="debug" select="$debug"/>
  </xsl:apply-templates>
</xsl:template>

<xsl:template match="html:*" mode="rdfa:resource-down">
  <xsl:param name="base" select="normalize-space((/html:html/html:head/html:base[@href])[1]/@href)"/>
  <xsl:param name="debug" select="$rdfa:DEBUG"/>

  <xsl:if test="$debug">
    <xsl:message>RESOURCE DOWN ACTUAL</xsl:message>
  </xsl:if>

  <xsl:text> </xsl:text>
  <xsl:variable name="_">
    <xsl:apply-templates select="." mode="rdfa:new-subject">
      <xsl:with-param name="base" select="$base"/>
      <xsl:with-param name="debug" select="$debug"/>
    </xsl:apply-templates>
  </xsl:variable>
  <xsl:if test="$debug">
    <xsl:message>look ma: <xsl:value-of select="$_"/></xsl:message>
  </xsl:if>
  <xsl:value-of select="$_"/>
  <xsl:text> </xsl:text>
</xsl:template>

<x:doc>
  <h3>rdfa:resource-up</h3>
</x:doc>

<xsl:template match="html:*[not(@rel|@rev|@about|@typeof|@resource|@href|@src)][(@property and @content|@datetime) or not(@property)]" mode="rdfa:resource-up">
  <xsl:param name="base" select="normalize-space((/html:html/html:head/html:base[@href])[1]/@href)"/>
  <xsl:param name="debug" select="$rdfa:DEBUG"/>

  <xsl:if test="$debug">
    <xsl:message>RESOURCE UP PASSTHRU</xsl:message>
  </xsl:if>

  <xsl:apply-templates select=".." mode="rdfa:resource-up">
    <xsl:with-param name="base" select="$base"/>
    <xsl:with-param name="debug" select="$debug"/>
  </xsl:apply-templates>
</xsl:template>

<!-- XXX do we even need this? -->
<xsl:template match="html:*" mode="rdfa:resource-up">
  <xsl:param name="base" select="normalize-space((/html:html/html:head/html:base[@href])[1]/@href)"/>
  <xsl:param name="debug" select="$rdfa:DEBUG"/>

  <xsl:if test="$debug">
    <xsl:message>RESOURCE UP ACTUAL</xsl:message>
  </xsl:if>

</xsl:template>

<x:doc>
  <h3>rdfa:locate-rel-down</h3>
</x:doc>

<!-- we have an (xhtml) element and it is assumed that we have the
     (rdf) subject already. the subject is either in this element or
     inherited from an ancestor. this is signified by
     $include-self. -->

<!-- if $include-self is true, @about and @typeof are okay, otherwise
     no except @typeof is okay -->

<!-- check for @rel|@rev -->
<!-- if @rel matches, check @resource|@href|@src -->
<!-- if no @resource|@href|@src, scan children -->
<!-- if @rel does not match or if there is a @rev, terminate -->
<!-- if neither @rel|@rev, check for @property and @resource|@href|@src -->

<!-- html:*[not(@rel|@rev|@about|@typeof|@resource|@href|@src)][not(@property) or (@property and @content)] -->
<!-- html:*[@rel or (not(@rel|@rev|@content|@datatype) and @property and @resource|@href|@src|@typeof] -->

<xsl:template match="*|@*" mode="rdfa:locate-rel-down">
<xsl:message terminate="yes">THIS rdfa:locate-rel-down SHOULD NEVER GET RUN</xsl:message>
</xsl:template>

<xsl:template match="html:*" mode="rdfa:locate-rel-down">
  <xsl:param name="debug" select="$rdfa:DEBUG"/>
  <xsl:if test="$debug">
    <xsl:message>rdfa:locate-rel-down: CALLED NOOP on <xsl:apply-templates select="." mode="element-dump"/></xsl:message>
  </xsl:if>
</xsl:template>

<xsl:template match="html:*[not(@rel|@rev|@resource|@href|@src)][not(@property) or (@property and @content|@datetime)]" mode="rdfa:locate-rel-down">
  <xsl:param name="predicate" select="''"/>
  <xsl:param name="base" select="normalize-space((/html:html/html:head/html:base[@href])[1]/@href)"/>
  <xsl:param name="include-self" select="false()"/>
  <xsl:param name="probe" select="false()"/>
  <xsl:param name="debug" select="$rdfa:DEBUG"/>

  <xsl:if test="not(string-length(normalize-space($predicate)))">
    <xsl:message terminate="yes">EMPTY PREDICATE: rdfa:locate-rel-down</xsl:message>
  </xsl:if>

  <xsl:if test="$debug">
    <xsl:message>rdfa:locate-rel-down: CALLED PASSTHRU ON <xsl:apply-templates select="." mode="element-dump"/></xsl:message>
  </xsl:if>

  <xsl:if test="$include-self or not(@about|@typeof)">
    <xsl:apply-templates select="html:*[@rel]|html:*[not(@rel|@rev)][@property and @resource|@href|@src|@typeof]|html:*[not(@rel|@rev|@resource|@href|@src)][not(@property) or (@property and @content|@datetime)]" mode="rdfa:locate-rel-down">
    <!--<xsl:apply-templates select="html:*" mode="rdfa:locate-rel-down">-->
      <xsl:with-param name="predicate" select="$predicate"/>
      <xsl:with-param name="base" select="$base"/>
      <xsl:with-param name="probe" select="$probe"/>
      <xsl:with-param name="debug" select="$debug"/>
    </xsl:apply-templates>
  </xsl:if>
</xsl:template>

<xsl:template match="html:*[@rel or (not(@rel|@rev|@content|@datetime|@datatype) and @property and @resource|@href|@src|@typeof)]" mode="rdfa:locate-rel-down">
  <xsl:param name="predicate" select="''"/>
  <xsl:param name="base" select="normalize-space((/html:html/html:head/html:base[@href])[1]/@href)"/>
  <xsl:param name="include-self" select="false()"/>
  <xsl:param name="probe" select="false()"/>
  <xsl:param name="debug" select="$rdfa:DEBUG"/>

  <xsl:if test="not(string-length(normalize-space($predicate)))">
    <xsl:message terminate="yes">EMPTY PREDICATE: rdfa:locate-rel-down</xsl:message>
  </xsl:if>

  <xsl:if test="$debug">
    <xsl:message>rdfa:locate-rel-down called on <xsl:apply-templates select="." mode="element-dump"/></xsl:message>
  </xsl:if>

  <xsl:choose>
    <xsl:when test="not($include-self) and (@about or (@rel and @typeof and not(@resource|@href|@src)))">
      <xsl:if test="$debug">
        <xsl:message>rdfa:locate-rel-down: skipping this element: <xsl:apply-templates select="." mode="element-dump"/></xsl:message>
      </xsl:if>
    </xsl:when>
    <xsl:when test="@rel">
      <xsl:variable name="_">
        <xsl:text> </xsl:text>
        <xsl:choose>
          <xsl:when test="contains(normalize-space(@rel), ' ')">
            <xsl:call-template name="rdfa:resolve-curie-list">
              <xsl:with-param name="list" select="@rel"/>
              <xsl:with-param name="node" select="."/>
              <xsl:with-param name="base" select="$base"/>
              <xsl:with-param name="resolve-terms" select="true()"/>
            </xsl:call-template>
          </xsl:when>
          <xsl:otherwise>
            <xsl:call-template name="rdfa:resolve-curie">
              <xsl:with-param name="curie" select="@rel"/>
              <xsl:with-param name="node" select="."/>
              <xsl:with-param name="base" select="$base"/>
              <xsl:with-param name="resolve-terms" select="true()"/>
            </xsl:call-template>
          </xsl:otherwise>
        </xsl:choose>
        <xsl:text> </xsl:text>
      </xsl:variable>

      <xsl:if test="$debug">
        <xsl:message>rdfa:locate-rel-down: (<xsl:value-of select="$_"/>) =~ <xsl:value-of select="$predicate"/> == <xsl:value-of select="contains($_, concat(' ', normalize-space($predicate), ' '))"/></xsl:message>
      </xsl:if>

      <xsl:if test="contains($_, concat(' ', $predicate, ' '))">
        <xsl:text> </xsl:text>
        <xsl:choose>
          <xsl:when test="$probe"><xsl:value-of select="true()"/></xsl:when>
          <xsl:when test="@resource">
            <xsl:call-template name="rdfa:resolve-curie">
              <xsl:with-param name="curie" select="@resource"/>
              <xsl:with-param name="node" select="."/>
              <xsl:with-param name="base" select="$base"/>
            </xsl:call-template>
            <xsl:if test="$debug">
              <xsl:message>rdfa:locate-rel-down: setting object to resource <xsl:value-of select="@resource"/></xsl:message>
            </xsl:if>
          </xsl:when>
          <xsl:when test="@href">
            <xsl:call-template name="uri:resolve-uri">
              <xsl:with-param name="uri" select="normalize-space(@href)"/>
              <xsl:with-param name="base" select="$base"/>
            </xsl:call-template>
            <xsl:if test="$debug">
              <xsl:message>rdfa:locate-rel-down: setting object to href <xsl:value-of select="@href"/></xsl:message>
            </xsl:if>
          </xsl:when>
          <xsl:when test="@src">
            <xsl:call-template name="uri:resolve-uri">
              <xsl:with-param name="uri" select="normalize-space(@src)"/>
              <xsl:with-param name="base" select="$base"/>
            </xsl:call-template>
            <xsl:if test="$debug">
              <xsl:message>rdfa:locate-rel-down: setting object to src <xsl:value-of select="@src"/></xsl:message>
            </xsl:if>
          </xsl:when>
          <xsl:otherwise>
            <xsl:apply-templates select="html:*" mode="rdfa:resource-down">
              <xsl:with-param name="base" select="$base"/>
            </xsl:apply-templates>
          </xsl:otherwise>
        </xsl:choose>
        <xsl:text> </xsl:text>
      </xsl:if>
    </xsl:when>
    <xsl:when test="@property">
      <xsl:variable name="_">
        <xsl:text> </xsl:text>
        <xsl:choose>
          <xsl:when test="contains(normalize-space(@property), ' ')">
            <xsl:call-template name="rdfa:resolve-curie-list">
              <xsl:with-param name="list" select="@property"/>
              <xsl:with-param name="node" select="."/>
              <xsl:with-param name="base" select="$base"/>
              <xsl:with-param name="resolve-terms" select="true()"/>
            </xsl:call-template>
          </xsl:when>
          <xsl:otherwise>
            <xsl:call-template name="rdfa:resolve-curie">
              <xsl:with-param name="curie" select="@property"/>
              <xsl:with-param name="node" select="."/>
              <xsl:with-param name="base" select="$base"/>
              <xsl:with-param name="resolve-terms" select="true()"/>
            </xsl:call-template>
          </xsl:otherwise>
        </xsl:choose>
        <xsl:text> </xsl:text>
      </xsl:variable>

      <xsl:if test="contains($_, concat(' ', $predicate, ' '))">
        <xsl:text> </xsl:text>
        <xsl:choose>
          <xsl:when test="$probe"><xsl:value-of select="true()"/></xsl:when>
          <xsl:when test="@resource">
            <xsl:call-template name="rdfa:resolve-curie">
              <xsl:with-param name="curie" select="@resource"/>
              <xsl:with-param name="node" select="."/>
              <xsl:with-param name="base" select="$base"/>
            </xsl:call-template>
          </xsl:when>
          <xsl:when test="@href">
            <xsl:call-template name="uri:resolve-uri">
              <xsl:with-param name="uri" select="normalize-space(@href)"/>
              <xsl:with-param name="base" select="$base"/>
            </xsl:call-template>
          </xsl:when>
          <xsl:when test="@src">
            <xsl:call-template name="uri:resolve-uri">
              <xsl:with-param name="uri" select="normalize-space(@src)"/>
              <xsl:with-param name="base" select="$base"/>
            </xsl:call-template>
          </xsl:when>
          <xsl:when test="@typeof and not(@about)">
            <xsl:value-of select="concat('_:', generate-id())"/>
          </xsl:when>
          <xsl:otherwise/>
        </xsl:choose>
        <xsl:text> </xsl:text>
      </xsl:if>
    </xsl:when>
    <xsl:otherwise/>
  </xsl:choose>

</xsl:template>

<x:doc>
  <h3>rdfa:locate-property</h3>
</x:doc>

<xsl:template xmlns:svg="http://www.w3.org/2000/svg" match="html:*|svg:*" mode="rdfa:locate-property"/><!--
  <xsl:message terminate="yes">THIS SHOULD NEVER BE RUN <xsl:apply-templates select="." mode="element-dump"/></xsl:message>
</xsl:template>-->
<xsl:template match="*|@*" mode="rdfa:locate-property">
  <xsl:message terminate="yes">THIS rdfa:locate-property SHOULD NEVER BE RUN</xsl:message>
</xsl:template>

<!--<xsl:template match=:html:*[not(@property) and (not(@rel|@rev) or @re-->

<!-- no about or typeof or rel or rev -->

<xsl:template match="html:html|html:head[@typeof]|html:body[@typeof]|html:*[not(@rel|@rev|@about|@resource|@href|@src|@typeof|@property)]" mode="rdfa:locate-property" priority="10">
  <xsl:param name="predicate" select="''"/>
  <xsl:param name="language" select="''"/>
  <xsl:param name="datatype" select="''"/>
  <xsl:param name="base" select="normalize-space((ancestor-or-self::html:html/html:head/html:base[@href])[1]/@href)"/>
  <xsl:param name="include-self" select="false()"/>
  <xsl:param name="probe" select="false()"/>
  <xsl:param name="debug" select="$rdfa:DEBUG"/>
  <!-- passthru -->
  <xsl:if test="$debug">
    <xsl:message>PT on <xsl:apply-templates select="." mode="element-dump"/></xsl:message>
  </xsl:if>
  <xsl:apply-templates select="html:*" mode="rdfa:locate-property">
    <xsl:with-param name="base" select="$base"/>
    <xsl:with-param name="predicate" select="$predicate"/>
    <xsl:with-param name="language" select="$language"/>
    <xsl:with-param name="datatype" select="$datatype"/>
    <xsl:with-param name="include-self" select="$include-self"/>
    <xsl:with-param name="probe" select="$probe"/>
    <xsl:with-param name="debug" select="$debug"/>
  </xsl:apply-templates>
</xsl:template>

<!--<xsl:template match="html:*[@property and (@rel|@rev or @content|@datatype)]" mode="rdfa:locate-property">-->
<xsl:template match="html:*[@property]" mode="rdfa:locate-property">
  <xsl:param name="predicate" select="''"/>
  <xsl:param name="language" select="''"/>
  <xsl:param name="datatype" select="''"/>
  <xsl:param name="base" select="normalize-space((ancestor-or-self::html:html/html:head/html:base[@href])[1]/@href)"/>
  <xsl:param name="include-self" select="false()"/>
  <xsl:param name="probe" select="false()"/>
  <xsl:param name="debug" select="$rdfa:DEBUG"/>

  <xsl:variable name="properties">
    <xsl:text> </xsl:text>
    <xsl:choose>
      <xsl:when test="contains(normalize-space(@property), ' ')">
        <xsl:call-template name="rdfa:resolve-curie-list">
          <xsl:with-param name="list" select="@property"/>
          <xsl:with-param name="node" select="."/>
          <xsl:with-param name="base" select="$base"/>
          <xsl:with-param name="resolve-terms" select="true()"/>
        </xsl:call-template>
      </xsl:when>
      <xsl:otherwise>
        <xsl:call-template name="rdfa:resolve-curie">
          <xsl:with-param name="curie" select="@property"/>
          <xsl:with-param name="node" select="."/>
          <xsl:with-param name="base" select="$base"/>
          <xsl:with-param name="resolve-terms" select="true()"/>
        </xsl:call-template>
      </xsl:otherwise>
    </xsl:choose>
    <xsl:text> </xsl:text>
  </xsl:variable>

  <xsl:variable name="this-language">
    <xsl:variable name="_" select="ancestor-or-self::html:*[@xml:lang|@lang][1]"/>
    <xsl:variable name="__">
    <xsl:choose>
      <xsl:when test="$_/@xml:lang"><xsl:value-of select="normalize-space(@xml:lang)"/></xsl:when>
      <xsl:when test="$_/@lang"><xsl:value-of select="normalize-space(@lang)"/></xsl:when>
      <xsl:otherwise/>
    </xsl:choose>
    </xsl:variable>
    <xsl:value-of select="translate($__, 'ABCDEFGHIJKLMNOPQRSTUVWXYZ_', 'abcdefghijklmnopqrstuvwxyz-')"/>
  </xsl:variable>

  <xsl:variable name="this-datatype">
    <xsl:if test="@datatype">
      <xsl:call-template name="rdfa:resolve-curie">
        <xsl:with-param name="curie" select="@datatype"/>
        <xsl:with-param name="node" select="."/>
        <xsl:with-param name="base" select="$base"/>
        <xsl:with-param name="resolve-terms" select="true()"/>
      </xsl:call-template>
    </xsl:if>
  </xsl:variable>

  <xsl:variable name="lang-ok" select="string-length($language) = 0 or (string-length($language) and ($language = $this-language or starts-with($this-language, concat($language, '-'))))"/>
  <xsl:variable name="dt-ok" select="string-length($datatype) = 0 or (string-length($datatype) and $datatype = $this-datatype)"/>
  <xsl:variable name="pred-ok" select="$lang-ok and $dt-ok and contains($properties, concat(' ', $predicate, ' '))"/>

  <xsl:choose>
    <!--<xsl:when test="$probe and contains($properties, concat(' ', $predicate, ' '))">-->
    <xsl:when test="$probe and $pred-ok">
      <xsl:value-of select="true()"/>
    </xsl:when>
    <!--<xsl:when test="contains($properties, concat(' ', $predicate, ' '))">-->
    <xsl:when test="$pred-ok">
      <xsl:value-of select="$rdfa:RECORD-SEP"/>
      <xsl:choose>
        <xsl:when test="$this-datatype = concat($rdfa:RDF-NS, 'XMLLiteral')">
          <xsl:value-of select="concat('#', generate-id(.))"/>
        </xsl:when>
        <xsl:when test="@content">
          <xsl:value-of select="@content"/>
        </xsl:when>
        <xsl:when test="@datetime">
          <xsl:value-of select="@datetime"/>
        </xsl:when>
        <xsl:otherwise><xsl:value-of select="string(.)"/></xsl:otherwise>
      </xsl:choose>
      <xsl:if test="not(string-length($datatype) or string-length($language))">
        <xsl:value-of select="$rdfa:UNIT-SEP"/>
        <xsl:choose>
          <xsl:when test="string-length($this-datatype)">
            <xsl:value-of select="$this-datatype"/>
          </xsl:when>
          <xsl:when test="string-length($this-language)">
            <xsl:value-of select="concat('@', $this-language)"/>
            <!--<xsl:value-of select="concat('@', translate($this-language, 'ABCDEFGHIJKLMNOPQRSTUVWXYZ_', 'abcdefghijklmnopqrstuvwxyz-'))"/>-->
          </xsl:when>
          <xsl:otherwise/>
        </xsl:choose>
      </xsl:if>
      <xsl:value-of select="$rdfa:RECORD-SEP"/>
    </xsl:when>
    <xsl:when test="@content|@datetime and not(@rel|@rev|@resource|@href|src) and ($include-self or not(@about|@typeof))">
      <xsl:apply-templates select="html:*" mode="rdfa:locate-property">
        <xsl:with-param name="base" select="$base"/>
        <xsl:with-param name="predicate" select="$predicate"/>
        <xsl:with-param name="language" select="$language"/>
        <xsl:with-param name="datatype" select="$datatype"/>
        <xsl:with-param name="include-self" select="$include-self"/>
        <xsl:with-param name="probe" select="$probe"/>
        <xsl:with-param name="debug" select="$debug"/>
      </xsl:apply-templates>
    </xsl:when>
    <xsl:otherwise/>
  </xsl:choose>

</xsl:template>

<x:doc>
  <h3>rdfa:locate-rev-down</h3>
</x:doc>

<xsl:template match="html:*" mode="rdfa:locate-rev-down">
  <xsl:param name="debug" select="$rdfa:DEBUG"/>
<xsl:if test="$debug">
  <xsl:message>CALLED REV NOOP (DOWN) ON <xsl:apply-templates select="." mode="element-dump"/></xsl:message>
</xsl:if>
</xsl:template>

<!-- XXX THE html:body PART IS WRONG -->
<xsl:template match="html:*[not(@rel|@rev|@resource|@href|@src)][not(@property) or (@property and @content|@datetime)]|html:body[not(@rev)]" mode="rdfa:locate-rev-down">
  <xsl:param name="predicate" select="''"/>
  <xsl:param name="base" select="normalize-space((ancestor-or-self::html:html/html:head/html:base[@href])[1]/@href)"/>
  <xsl:param name="probe" select="false()"/>
  <xsl:param name="debug" select="$rdfa:DEBUG"/>

  <xsl:if test="$debug">
    <xsl:message>rdfa:locate-rev-down: CALLED PASSTHRU ON <xsl:apply-templates select="." mode="element-dump"/></xsl:message>
  </xsl:if>

  <xsl:apply-templates select="html:*[@rev]|html:*[not(@rel|@rev|@about|@typeof|@resource|@href|@src)][not(@property) or (@property and @content|@datetime)]" mode="rdfa:locate-rev-down">
    <xsl:with-param name="predicate" select="$predicate"/>
    <xsl:with-param name="base" select="$base"/>
    <xsl:with-param name="probe" select="$probe"/>
    <xsl:with-param name="debug" select="$debug"/>
  </xsl:apply-templates>
</xsl:template>

<xsl:template match="html:*[@rev]" mode="rdfa:locate-rev-down">
  <xsl:param name="predicate" select="''"/>
  <xsl:param name="base" select="normalize-space((ancestor-or-self::html:html/html:head/html:base[@href])[1]/@href)"/>
  <xsl:param name="include-self" select="false()"/>
  <xsl:param name="probe" select="false()"/>
  <xsl:param name="debug" select="$rdfa:DEBUG"/>

  <!-- this is very close to locate-rel-down except it does @rev and not
       @property -->

  <xsl:if test="$debug">
    <xsl:message>rdfa:locate-rev-down called on <xsl:apply-templates select="." mode="element-dump"/></xsl:message>
  </xsl:if>

  <xsl:choose>
    <xsl:when test="not($include-self) and (@about or (@typeof and not(@resource|@href|@src)))"/>
    <xsl:otherwise>
      <xsl:variable name="_">
        <xsl:text> </xsl:text>
        <xsl:choose>
          <xsl:when test="contains(normalize-space(@rev), ' ')">
            <xsl:call-template name="rdfa:resolve-curie-list">
              <xsl:with-param name="list" select="@rev"/>
              <xsl:with-param name="node" select="."/>
              <xsl:with-param name="base" select="$base"/>
              <xsl:with-param name="resolve-terms" select="true()"/>
            </xsl:call-template>
          </xsl:when>
          <xsl:otherwise>
            <xsl:call-template name="rdfa:resolve-curie">
              <xsl:with-param name="curie" select="@rev"/>
              <xsl:with-param name="node" select="."/>
              <xsl:with-param name="base" select="$base"/>
              <xsl:with-param name="resolve-terms" select="true()"/>
            </xsl:call-template>
          </xsl:otherwise>
        </xsl:choose>
        <xsl:text> </xsl:text>
      </xsl:variable>

      <xsl:if test="contains($_, concat(' ', $predicate, ' '))">
        <xsl:text> </xsl:text>
        <xsl:choose>
          <xsl:when test="$probe"><xsl:value-of select="true()"/></xsl:when>
          <xsl:when test="@resource">
            <xsl:call-template name="rdfa:resolve-curie">
              <xsl:with-param name="curie" select="@resource"/>
              <xsl:with-param name="node" select="."/>
              <xsl:with-param name="base" select="$base"/>
            </xsl:call-template>
          </xsl:when>
          <xsl:when test="@href">
            <xsl:call-template name="uri:resolve-uri">
              <xsl:with-param name="uri" select="normalize-space(@href)"/>
              <xsl:with-param name="base" select="$base"/>
            </xsl:call-template>
          </xsl:when>
          <xsl:when test="@src">
            <xsl:call-template name="uri:resolve-uri">
              <xsl:with-param name="uri" select="normalize-space(@src)"/>
              <xsl:with-param name="base" select="$base"/>
            </xsl:call-template>
          </xsl:when>
          <xsl:otherwise>
            <xsl:apply-templates select="html:*" mode="rdfa:resource-down">
              <xsl:with-param name="base" select="$base"/>
              <xsl:with-param name="debug" select="$debug"/>
            </xsl:apply-templates>
          </xsl:otherwise>
        </xsl:choose>
        <xsl:text> </xsl:text>
      </xsl:if>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<x:doc>
  <h3>rdfa:locate-rev-up</h3>
</x:doc>

<xsl:template match="*|@*" mode="rdfa:locate-rev-up">
  <xsl:message terminate="yes">THIS SHOULD NEVER GET RUN</xsl:message>
</xsl:template>

<xsl:template match="html:*" mode="rdfa:locate-rev-up">
  <xsl:param name="debug" select="$rdfa:DEBUG"/>
<xsl:if test="$debug">
  <xsl:message>CALLED REV NOOP (UP) ON <xsl:apply-templates select="." mode="element-dump"/></xsl:message>
</xsl:if>
</xsl:template>

<xsl:template match="html:*[not(@rel|@rev|@about|@typeof|@resource|@href|@src)][not(@property) or (@property and @content|@datetime)]" mode="rdfa:locate-rev-up">
  <xsl:param name="predicate" select="''"/>
  <xsl:param name="base" select="normalize-space((ancestor-or-self::html:html/html:head/html:base[@href])[1]/@href)"/>
  <xsl:param name="probe" select="false()"/>
  <xsl:param name="debug" select="$rdfa:DEBUG"/>

  <xsl:if test="$debug">
    <xsl:message>CALLED REV PASSTHRU ON <xsl:value-of select="local-name()"/></xsl:message>
  </xsl:if>

  <xsl:apply-templates select="parent::html:*[@rev]|parent::html:*[not(@rel|@rev|@about|@typeof|@resource|@href|@src)][not(@property) or (@property and @content|@datetime)]" mode="rdfa:locate-rev-up">
    <xsl:with-param name="predicate" select="$predicate"/>
    <xsl:with-param name="base" select="$base"/>
    <xsl:with-param name="probe" select="$probe"/>
    <xsl:with-param name="debug" select="$debug"/>
  </xsl:apply-templates>
</xsl:template>

<xsl:template match="html:*[@rev]" mode="rdfa:locate-rev-up">
  <xsl:param name="predicate" select="''"/>
  <xsl:param name="base" select="normalize-space((ancestor-or-self::html:html/html:head/html:base[@href])[1]/@href)"/>
  <xsl:param name="include-self" select="false()"/>
  <xsl:param name="probe" select="false()"/>
  <xsl:param name="debug" select="$rdfa:DEBUG"/>

  <!-- the rev has to exist *and* match for further processing or
       otherwise there can't be any other resource/macro node -->

  <xsl:choose>
    <xsl:when test="not($include-self) and (@resource|@href|@src or (@typeof and not(@about)))"/>
    <xsl:otherwise>
      <xsl:variable name="_">
        <xsl:text> </xsl:text>
        <xsl:choose>
          <xsl:when test="contains(normalize-space(@rev), ' ')">
            <xsl:call-template name="rdfa:resolve-curie-list">
              <xsl:with-param name="list" select="@rev"/>
              <xsl:with-param name="node" select="."/>
              <xsl:with-param name="base" select="$base"/>
              <xsl:with-param name="resolve-terms" select="true()"/>
            </xsl:call-template>
          </xsl:when>
          <xsl:otherwise>
            <xsl:call-template name="rdfa:resolve-curie">
              <xsl:with-param name="curie" select="@rev"/>
              <xsl:with-param name="node" select="."/>
              <xsl:with-param name="base" select="$base"/>
              <xsl:with-param name="resolve-terms" select="true()"/>
            </xsl:call-template>
          </xsl:otherwise>
        </xsl:choose>
        <xsl:text> </xsl:text>
      </xsl:variable>

      <xsl:if test="contains($_, concat(' ', $predicate, ' '))">
        <xsl:text> </xsl:text>
        <xsl:choose>
          <xsl:when test="$probe"><xsl:value-of select="true()"/></xsl:when>
          <xsl:otherwise>
            <xsl:apply-templates select="." mode="rdfa:new-subject">
              <xsl:with-param name="base" select="$base"/>
            </xsl:apply-templates>
          </xsl:otherwise>
        </xsl:choose>
        <xsl:text> </xsl:text>
      </xsl:if>
    </xsl:otherwise>
  </xsl:choose>

</xsl:template>

<x:doc>
  <h3>rdfa:locate-rel-up</h3>
</x:doc>

<xsl:template match="*|@*" mode="rdfa:locate-rel-up">
  <xsl:message terminate="yes">THIS SHOULD NEVER GET RUN</xsl:message>
</xsl:template>

<xsl:template match="html:*" mode="rdfa:locate-rel-up"/>

<!-- this xpath is just copied so it might not be right or it might be -->
<xsl:template match="html:*[not(@rel|@rev|@about|@typeof|@resource|@href|@src)][not(@property) or (@property and @content|@datetime)]" mode="rdfa:locate-rev-up">
  <xsl:param name="predicate" select="''"/>
  <xsl:param name="base" select="normalize-space((ancestor-or-self::html:html/html:head/html:base[@href])[1]/@href)"/>
  <xsl:param name="probe" select="false()"/>
  <xsl:param name="debug" select="$rdfa:DEBUG"/>

  <xsl:if test="$debug">
    <xsl:message>CALLED REL UP PASSTHRU ON <xsl:value-of select="local-name()"/></xsl:message>
  </xsl:if>

  <xsl:apply-templates select="parent::html:*[@rel or (not(@rel|@rev|@content|@datetime|@datatype) and @property and @resource|@href|@src|@typeof)]|parent::html:*[not(@rel|@rev|@about|@typeof|@resource|@href|@src)][not(@property) or (@property and @content|@datetime)]" mode="rdfa:locate-rev-up">
    <xsl:with-param name="predicate" select="$predicate"/>
    <xsl:with-param name="base" select="$base"/>
    <xsl:with-param name="probe" select="$probe"/>
    <xsl:with-param name="debug" select="$debug"/>
  </xsl:apply-templates>
</xsl:template>

<xsl:template match="html:*[@rel or (not(@rel|@rev|@content|@datetime|@datatype) and @property and @resource|@href|@src|@typeof)]" mode="rdfa:locate-rel-up">
  <xsl:param name="predicate" select="''"/>
  <xsl:param name="base" select="normalize-space((ancestor-or-self::html:html/html:head/html:base[@href])[1]/@href)"/>
  <xsl:param name="include-self" select="false()"/>
  <xsl:param name="probe" select="false()"/>
  <xsl:param name="debug" select="$rdfa:DEBUG"/>

  <!-- template filter includes @property if $include-self -->

  <xsl:variable name="p">
    <xsl:choose>
      <xsl:when test="@rel"><xsl:value-of select="@rel"/></xsl:when>
      <xsl:when test="@property"><xsl:value-of select="@property"/></xsl:when>
      <xsl:otherwise/>
    </xsl:choose>
  </xsl:variable>

  <xsl:choose>
    <xsl:when test="not($include-self) and (@resource|@href|@src or (@typeof and not(@about)))"/>
    <xsl:when test="string-length(normalize-space($p))">

      <xsl:variable name="_">
        <xsl:text> </xsl:text>
        <xsl:choose>
          <xsl:when test="contains(normalize-space($p), ' ')">
            <xsl:call-template name="rdfa:resolve-curie-list">
              <xsl:with-param name="list" select="$p"/>
              <xsl:with-param name="node" select="."/>
              <xsl:with-param name="base" select="$base"/>
              <xsl:with-param name="resolve-terms" select="true()"/>
            </xsl:call-template>
          </xsl:when>
          <xsl:otherwise>
            <xsl:call-template name="rdfa:resolve-curie">
              <xsl:with-param name="curie" select="$p"/>
              <xsl:with-param name="node" select="."/>
              <xsl:with-param name="base" select="$base"/>
              <xsl:with-param name="resolve-terms" select="true()"/>
            </xsl:call-template>
          </xsl:otherwise>
        </xsl:choose>
        <xsl:text> </xsl:text>
      </xsl:variable>

      <xsl:if test="contains($_, concat(' ', $predicate, ' '))">
        <xsl:text> </xsl:text>
        <xsl:choose>
          <xsl:when test="$probe"><xsl:value-of select="true()"/></xsl:when>
          <xsl:otherwise>
            <xsl:apply-templates select="." mode="rdfa:new-subject">
              <xsl:with-param name="base" select="$base"/>
            </xsl:apply-templates>
          </xsl:otherwise>
        </xsl:choose>
        <xsl:text> </xsl:text>
      </xsl:if>
    </xsl:when>
    <xsl:otherwise/>
  </xsl:choose>

</xsl:template>

<x:doc>
  <h3>rdfa:subject-node</h3>
</x:doc>

<!--
    this template is handed a resource node from either of the keys
    rdfa:curie-node or rdfa:uri-node, and will usually be an
    attribute. the current element (not to be confused with the
    current *node*, which could be either an element or an attribute)
    is evaluated to determine how to traverse to find the object
    resource.
-->
<!-- bnodes can actually be either subjects or objects -->

<!-- luckily it looks like there is only ever one bnode per element
     evaluation -->

<!-- bnodes are only ever subjects if the node does not contain
     @rel|@rev, and if it either does not contain @property, or it
     contains @content|@datatype -->


<xsl:template match="html:*|html:*/@*" mode="rdfa:subject-node"/>
<xsl:template match="html:*[not(ancestor::*[@property and not(@content|@datetime)])]|html:*[not(ancestor::*[@property and not(@content|@datetime)])]/@*" mode="rdfa:subject-node">
  <xsl:param name="subject" select="''"/>
  <xsl:param name="predicate" select="''"/>
  <xsl:param name="base" select="normalize-space((ancestor-or-self::html:html/html:head/html:base[@href])[1]/@href)"/>
  <xsl:param name="probe" select="false()"/>
  <xsl:param name="debug" select="$rdfa:DEBUG"/>

  <!-- i suppose the first thing to do is determine if we're looking a
       subject, an object, or just a meaningless resource -->

  <!-- the parenthesis puts this expression in document order; parent
       node (..) always precedes the current node in document order. -->
  <xsl:variable name="element" select="(self::*|..)[last()]"/>

  <xsl:if test="$debug">
    <xsl:message>
      <xsl:text>rdfa:subject-node: S-P-O</xsl:text>
      <xsl:value-of select="$subject"/><xsl:text> </xsl:text>
      <xsl:value-of select="$predicate"/><xsl:text> </xsl:text>
      <xsl:apply-templates select="$element" mode="element-dump"/>
    </xsl:message>
  </xsl:if>

  <xsl:if test="$predicate = concat($rdfa:RDF-NS, 'type') and $element/@typeof">
    <xsl:choose>
      <xsl:when test="$probe"><xsl:value-of select="true()"/></xsl:when>
      <xsl:otherwise>
        <xsl:text> </xsl:text>
        <xsl:apply-templates select="." mode="rdfa:my-typeof">
          <xsl:with-param name="base" select="$base"/>
        </xsl:apply-templates>
        <xsl:text> </xsl:text>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:if>

  <xsl:variable name="is-subject">
    <xsl:apply-templates select="." mode="rdfa:is-subject"/>
  </xsl:variable>
  <xsl:choose>
    <xsl:when test="string-length($is-subject)">
      <!-- descendant-or-self rel|property; ancestor rev -->
      <xsl:if test="$debug">
        <xsl:message>rdfa:subject-node called with SUBJECT <xsl:apply-templates select="$element" mode="element-dump"/></xsl:message>
      </xsl:if>
      <!-- omg forgetting $element here literally cost me 5 hours -->
      <xsl:apply-templates select="$element/parent::html:*[@rev]|$element/parent::html:*[not(@rel|@rev|@about|@typeof|@resource|@href|@src)][not(@property) or (@property and @content|@datetime)]" mode="rdfa:locate-rev-up">
        <xsl:with-param name="predicate" select="$predicate"/>
        <xsl:with-param name="base" select="$base"/>
        <xsl:with-param name="include-self" select="false()"/>
        <xsl:with-param name="probe" select="$probe"/>
        <xsl:with-param name="debug" select="$debug"/>
      </xsl:apply-templates>
      <!-- if i remove this -->
      <!--<xsl:apply-templates select="self::html:*[@rel]|self::html:*[not(@rel|@rev)][(@property and @content) or not(@property)]" mode="rdfa:locate-rel-down">-->
      <xsl:apply-templates select="$element" mode="rdfa:locate-rel-down">
        <xsl:with-param name="predicate" select="$predicate"/>
        <xsl:with-param name="base" select="$base"/>
        <xsl:with-param name="include-self" select="true()"/>
        <xsl:with-param name="probe" select="$probe"/>
        <xsl:with-param name="debug" select="$debug"/>
      </xsl:apply-templates>
    </xsl:when>
    <xsl:otherwise>
      <!-- descendant rel|property; ancestor-or-self rev -->
      <xsl:if test="$debug">
        <xsl:message>rdfa:subject-node called with OBJECT</xsl:message>
      </xsl:if>
      <xsl:apply-templates select="$element/self::html:*[@rev]|$element/self::html:*[not(@rel|@rev|@about|@typeof|@resource|@href|@src)][not(@property) or (@property and @content|@datetime)]" mode="rdfa:locate-rev-up">
        <!--<xsl:apply-templates select="." mode="rdfa:locate-rev-up">-->
        <xsl:with-param name="predicate" select="$predicate"/>
        <xsl:with-param name="base" select="$base"/>
        <xsl:with-param name="include-self" select="true()"/>
        <xsl:with-param name="probe" select="$probe"/>
        <xsl:with-param name="debug" select="$debug"/>
      </xsl:apply-templates>
      <xsl:apply-templates select="$element/html:*[@rel]|$element/html:*[not(@rel|@rev)][(@property and @content|@datetime) or not(@property)]|$element/html:*[not(@rel|@rev|@about|@typeof|@resource|@href|@src)][not(@property) or (@property and @content|@datetime)]" mode="rdfa:locate-rel-down">
        <xsl:with-param name="predicate" select="$predicate"/>
        <xsl:with-param name="base" select="$base"/>
        <xsl:with-param name="include-self" select="false()"/>
        <xsl:with-param name="probe" select="$probe"/>
        <xsl:with-param name="debug" select="$debug"/>
      </xsl:apply-templates>
    </xsl:otherwise>
  </xsl:choose>

</xsl:template>

<x:doc>
  <h3>rdfa:object-node</h3>
</x:doc>

<xsl:template match="html:*|html:*/@*" mode="rdfa:object-node">
  <xsl:param name="predicate" select="''"/>
  <xsl:param name="object" select="''"/>
  <xsl:param name="base" select="normalize-space((ancestor-or-self::html:html/html:head/html:base[@href])[1]/@href)"/>
  <xsl:param name="debug" select="$rdfa:DEBUG"/>
  <xsl:variable name="probe" select="false()"/>

  <xsl:variable name="element" select="(self::*|..)[last()]"/>

  <xsl:if test="$debug">
  <xsl:message>
    <xsl:text>O-P-S: </xsl:text>
    <xsl:value-of select="$object"/><xsl:text> </xsl:text>
    <xsl:value-of select="$predicate"/><xsl:text> </xsl:text>
    <xsl:apply-templates select="$element" mode="element-dump"/>
  </xsl:message>
  </xsl:if>

  <xsl:variable name="is-subject">
    <xsl:apply-templates select="." mode="rdfa:is-subject"/>
  </xsl:variable>

  <xsl:choose>
    <xsl:when test="string-length($is-subject)">
      <xsl:apply-templates select="$element/parent::html:*[@rel]|$element/parent::html:*[not(@rel|@rev|@about|@typeof|@resource|@href|@src)][not(@property) or (@property and @content|@datetime)]" mode="rdfa:locate-rel-up">
        <xsl:with-param name="predicate" select="$predicate"/>
        <xsl:with-param name="base" select="$base"/>
        <xsl:with-param name="include-self" select="false()"/>
        <xsl:with-param name="probe" select="$probe"/>
        <xsl:with-param name="debug" select="$debug"/>
      </xsl:apply-templates>
      <!--<xsl:apply-templates select="self::html:*[@rev]|self::html:*[not(@rel|@rev)][(@property and @content) or not(@property)]" mode="rdfa:locate-rev-down">-->
      <xsl:apply-templates select="$element" mode="rdfa:locate-rev-down">
        <xsl:with-param name="predicate" select="$predicate"/>
        <xsl:with-param name="base" select="$base"/>
        <xsl:with-param name="include-self" select="true()"/>
        <xsl:with-param name="probe" select="$probe"/>
        <xsl:with-param name="debug" select="$debug"/>
      </xsl:apply-templates>
    </xsl:when>
    <xsl:otherwise>
      <xsl:apply-templates select="$element/self::html:*[@rel]|$element/self::html:*[not(@rel|@rev|@about|@typeof|@resource|@href|@src)][not(@property) or (@property and @content|@datetime)]" mode="rdfa:locate-rel-up">
        <!--<xsl:apply-templates select="." mode="rdfa:locate-rel-up">-->
        <xsl:with-param name="predicate" select="$predicate"/>
        <xsl:with-param name="base" select="$base"/>
        <xsl:with-param name="include-self" select="true()"/>
        <xsl:with-param name="probe" select="$probe"/>
        <xsl:with-param name="debug" select="$debug"/>
      </xsl:apply-templates>
      <xsl:apply-templates select="$element/html:*[@rev]|$element/html:*[not(@rel|@rev)][(@property and @content|@datetime) or not(@property)]" mode="rdfa:locate-rev-down">
        <xsl:with-param name="predicate" select="$predicate"/>
        <xsl:with-param name="base" select="$base"/>
        <xsl:with-param name="include-self" select="false()"/>
        <xsl:with-param name="probe" select="$probe"/>
        <xsl:with-param name="debug" select="$debug"/>
      </xsl:apply-templates>
    </xsl:otherwise>
  </xsl:choose>

</xsl:template>

<x:doc>
  <h3>rdfa:object-resource-internal</h3>
</x:doc>

<xsl:template match="html:*" mode="rdfa:object-resource-internal">
  <xsl:param name="current" select="."/>
  <xsl:param name="base" select="normalize-space(($current/ancestor-or-self::html:html/html:head/html:base[@href])[1]/@href)"/>
  <xsl:param name="subject" select="''"/>
  <xsl:param name="predicate" select="''"/>
  <xsl:param name="prefixes">
    <xsl:apply-templates select="$current" mode="rdfa:prefix-stack"/>
  </xsl:param>
  <xsl:param name="probe" select="false()"/>
  <xsl:param name="debug" select="$rdfa:DEBUG"/>

  <xsl:variable name="resource" select="$subject"/>

  <xsl:variable name="bnode-id">
    <xsl:choose>
      <xsl:when test="starts-with($resource, '_:')">
        <xsl:value-of select="substring-after($resource, '_:')"/>
      </xsl:when>
      <xsl:otherwise>&lt;&gt;</xsl:otherwise>
    </xsl:choose>
  </xsl:variable>
  <xsl:variable name="blank-nodes" select="key('rdfa:reverse-node-id', $bnode-id)"/>

  <xsl:variable name="root-resource">
    <xsl:apply-templates select="ancestor-or-self::html:html[1]" mode="rdfa:new-subject">
      <xsl:with-param name="base" select="$base"/>
      <xsl:with-param name="debug" select="$debug"/>
    </xsl:apply-templates>
  </xsl:variable>
  <xsl:if test="$debug">
    <xsl:message>self: <xsl:value-of select="$resource"/> root: <xsl:value-of select="$root-resource"/></xsl:message>
  </xsl:if>

  <!-- okay this is clever -->
  <xsl:variable name="is-root" select="number($root-resource = $resource)"/>
  <xsl:variable name="root-nodes" select="(ancestor-or-self::html:html[$is-root]|ancestor-or-self::html:html[$is-root]/html:head[1]|ancestor-or-self::html:html[$is-root]/html:body[1])[not(@about|@resource|@href|@src)]"/>

  <xsl:variable name="_rel">
    <xsl:call-template name="uri:make-relative-uri">
      <xsl:with-param name="uri" select="$resource"/>
      <xsl:with-param name="base" select="$base"/>
      <xsl:with-param name="strict" select="true()"/>
    </xsl:call-template>
  </xsl:variable>

  <xsl:variable name="resource-rel-strict">
    <xsl:choose>
      <xsl:when test="$_rel != $resource">
        <xsl:value-of select="$_rel"/>
      </xsl:when>
      <xsl:otherwise>&lt;&gt;</xsl:otherwise>
    </xsl:choose>
  </xsl:variable>
  <xsl:variable name="rel-strict-nodes" select="key('rdfa:uri-node', $resource-rel-strict)"/>

  <xsl:variable name="resource-rel-lax">
    <xsl:variable name="_">
      <xsl:call-template name="uri:make-relative-uri">
        <xsl:with-param name="uri" select="$resource"/>
        <xsl:with-param name="base" select="$base"/>
        <xsl:with-param name="strict" select="false()"/>
      </xsl:call-template>
    </xsl:variable>
    <xsl:choose>
      <xsl:when test="$_rel != $resource and $_ != $_rel">
        <xsl:value-of select="$_"/>
      </xsl:when>
      <xsl:otherwise>&lt;&gt;</xsl:otherwise>
    </xsl:choose>
  </xsl:variable>
  <xsl:variable name="rel-lax-nodes" select="key('rdfa:uri-node', $resource-rel-lax)"/>

  <xsl:variable name="resource-rel-full">
    <xsl:choose>
      <xsl:when test="$_rel != $resource">
        <xsl:call-template name="uri:local-part">
          <xsl:with-param name="uri" select="$resource"/>
          <xsl:with-param name="base" select="$base"/>
        </xsl:call-template>
      </xsl:when>
      <xsl:otherwise>&lt;&gt;</xsl:otherwise>
    </xsl:choose>
  </xsl:variable>
  <xsl:variable name="rel-full-nodes" select="key('rdfa:uri-node', $resource-rel-full)"/>

  <xsl:variable name="resource-qs-only">
    <xsl:variable name="_r" select="substring-before($resource, '?')"/>
    <xsl:variable name="_b" select="substring-after($base, $_r)"/>
    <xsl:variable name="_q" select="concat('?', substring-after($resource, '?'))"/>
    <xsl:choose>
      <xsl:when test="contains($resource, '?') and starts-with($base, $_r) and $_rel != $_q and ($_b = '' or starts-with($_b, '?') or starts-with($_b, '#'))">
        <xsl:value-of select="$_q"/>
      </xsl:when>
      <xsl:otherwise>&lt;&gt;</xsl:otherwise>
    </xsl:choose>
  </xsl:variable>
  <xsl:variable name="qs-only-nodes" select="key('rdfa:uri-node', $resource-qs-only)"/>

  <xsl:variable name="resource-curie">
    <xsl:variable name="_">
      <xsl:call-template name="rdfa:make-curie">
        <xsl:with-param name="uri"      select="$resource"/>
        <xsl:with-param name="node"     select="$current"/>
        <xsl:with-param name="prefixes" select="$prefixes"/>
      </xsl:call-template>
    </xsl:variable>
    <xsl:choose>
      <xsl:when test="string-length($_)"><xsl:value-of select="$_"/></xsl:when>
      <xsl:otherwise>&lt;&gt;</xsl:otherwise>
    </xsl:choose>
  </xsl:variable>
  <xsl:variable name="curie-nodes" select="key('rdfa:curie-node', $resource-curie)|key('rdfa:curie-node', concat('[', $resource-curie, ']'))"/>

  <xsl:if test="$debug">
    <xsl:message>NODES: <xsl:value-of select="count(key('rdfa:uri-node', $resource)|$blank-nodes|$root-nodes|$rel-strict-nodes|$rel-lax-nodes|$rel-full-nodes|$qs-only-nodes|$curie-nodes)"/></xsl:message>
    <xsl:for-each select="key('rdfa:uri-node', $resource)|$blank-nodes|$root-nodes|$rel-strict-nodes|$rel-lax-nodes|$rel-full-nodes|$qs-only-nodes|$curie-nodes">
      <xsl:message>
        <xsl:apply-templates select="." mode="element-dump"/>
      </xsl:message>
    </xsl:for-each>
  </xsl:if>

  <xsl:apply-templates select="key('rdfa:uri-node', $resource)|$blank-nodes|$root-nodes|$rel-strict-nodes|$rel-lax-nodes|$rel-full-nodes|$qs-only-nodes|$curie-nodes" mode="rdfa:subject-node">
    <xsl:with-param name="subject" select="$resource"/>
    <xsl:with-param name="predicate" select="$predicate"/>
    <xsl:with-param name="base" select="$base"/>
    <xsl:with-param name="probe" select="$probe"/>
    <xsl:with-param name="debug" select="$debug"/>
  </xsl:apply-templates>

</xsl:template>

<x:doc>
  <h3>rdfa:object-resources</h3>
  <p>this is part of the actual interface</p>
</x:doc>

<xsl:template match="html:*" mode="rdfa:object-resources" name="rdfa:object-resources">
  <xsl:param name="current"    select="."/>
  <xsl:param name="local-base" select="normalize-space(($current/ancestor-or-self::html:html/html:head/html:base[@href])[1]/@href)"/>
  <xsl:param name="base"       select="$local-base"/>
  <xsl:param name="subject"    select="$base"/>
  <xsl:param name="predicate"  select="''"/>
  <xsl:param name="single"     select="false()"/>
  <xsl:param name="traverse"   select="false()"/>
  <xsl:param name="debug"      select="$rdfa:DEBUG"/>
  <xsl:param name="raw"        select="false()"/>
  <xsl:param name="prefixes">
    <xsl:apply-templates select="$current" mode="rdfa:prefix-stack"/>
  </xsl:param>

  <xsl:variable name="resource-list">
    <xsl:choose>
      <xsl:when test="contains(normalize-space($subject), ' ')">
        <xsl:call-template name="rdfa:resolve-curie-list">
          <xsl:with-param name="list">
            <xsl:call-template name="str:unique-tokens">
              <xsl:with-param name="string" select="$subject"/>
            </xsl:call-template>
          </xsl:with-param>
          <xsl:with-param name="node" select="$current"/>
          <xsl:with-param name="base" select="$base"/>
          <xsl:with-param name="prefixes" select="$prefixes"/>
          <xsl:with-param name="resolve-terms" select="true()"/>
        </xsl:call-template>
      </xsl:when>
      <xsl:otherwise>
        <xsl:call-template name="rdfa:resolve-curie">
          <xsl:with-param name="curie" select="$subject"/>
          <xsl:with-param name="node" select="$current"/>
          <xsl:with-param name="base" select="$base"/>
          <xsl:with-param name="prefixes" select="$prefixes"/>
          <xsl:with-param name="resolve-terms" select="true()"/>
        </xsl:call-template>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:variable>

  <xsl:variable name="first-resource">
    <xsl:choose>
      <xsl:when test="contains(normalize-space($resource-list), ' ')">
        <xsl:value-of select="substring-before(normalize-space($resource-list), ' ')"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="normalize-space($resource-list)"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:variable>

  <xsl:variable name="predicate-absolute">
    <xsl:call-template name="rdfa:resolve-curie">
      <xsl:with-param name="curie" select="$predicate"/>
      <xsl:with-param name="node" select="$current"/>
      <xsl:with-param name="base" select="$base"/>
      <xsl:with-param name="resolve-terms" select="true()"/>
    </xsl:call-template>
  </xsl:variable>

  <xsl:if test="$debug">
    <xsl:message>Resolved <xsl:value-of select="$predicate"/> to &lt;<xsl:value-of select="$predicate-absolute"/>&gt;.</xsl:message>
  </xsl:if>

  <xsl:variable name="raw-resource-list">
    <xsl:text> </xsl:text>

    <xsl:choose>
      <xsl:when test="$traverse">
        <xsl:if test="$debug">
          <xsl:message>rdfa:object-resources traversing to <xsl:value-of select="$first-resource"/></xsl:message>
        </xsl:if>

	<xsl:variable name="doc">
	  <xsl:call-template name="uri:document-for-uri">
	    <xsl:with-param name="uri" select="$first-resource"/>
	  </xsl:call-template>
	</xsl:variable>
	<xsl:apply-templates select="document($doc)/*" mode="rdfa:object-resource-internal">
	  <xsl:with-param name="subject"    select="$first-resource"/>
	  <xsl:with-param name="predicate"  select="$predicate-absolute"/>
	  <!--<xsl:with-param name="base"       select="$base"/>
	  <xsl:with-param name="prefixes"   select="$prefixes"/>-->
	  <xsl:with-param name="debug"      select="$debug"/>
	</xsl:apply-templates>
      </xsl:when>
      <xsl:otherwise>
	<xsl:apply-templates select="$current" mode="rdfa:object-resource-internal">
	  <xsl:with-param name="subject"    select="$first-resource"/>
	  <xsl:with-param name="predicate"  select="$predicate-absolute"/>
	  <xsl:with-param name="base"       select="$base"/>
	  <xsl:with-param name="prefixes"   select="$prefixes"/>
	  <xsl:with-param name="debug"      select="$debug"/>
	</xsl:apply-templates>
      </xsl:otherwise>
    </xsl:choose>

    <xsl:if test="string-length(substring-after(normalize-space($resource-list), ' '))">
      <xsl:text> </xsl:text>
      <xsl:call-template name="rdfa:object-resources">
        <xsl:with-param name="subject"    select="substring-after(normalize-space($resource-list), ' ')"/>
        <xsl:with-param name="predicate"  select="$predicate-absolute"/>
        <xsl:with-param name="current"    select="$current"/>
        <xsl:with-param name="base"       select="$base"/>
        <xsl:with-param name="single"     select="$single"/>
        <xsl:with-param name="traverse"   select="$traverse"/>
        <xsl:with-param name="prefixes"   select="$prefixes"/>
        <xsl:with-param name="debug"      select="$debug"/>
      </xsl:call-template>
    </xsl:if>
  </xsl:variable>

  <xsl:choose>
    <xsl:when test="$raw">
      <xsl:value-of select="$raw-resource-list"/>
    </xsl:when>
    <xsl:when test="$single and contains(normalize-space($raw-resource-list), ' ')">
      <xsl:value-of select="substring-before(normalize-space($raw-resource-list), ' ')"/>
    </xsl:when>
    <xsl:when test="not(contains(normalize-space($raw-resource-list), ' '))">
      <xsl:value-of select="normalize-space($raw-resource-list)"/>
    </xsl:when>
    <xsl:otherwise>
      <xsl:call-template name="str:unique-tokens">
        <xsl:with-param name="string" select="$raw-resource-list"/>
      </xsl:call-template>
    </xsl:otherwise>
  </xsl:choose>

</xsl:template>

<x:doc>
  <h3>rdfa:subject-resource-internal</h3>
</x:doc>

<xsl:template match="html:*" mode="rdfa:subject-resource-internal">
  <xsl:param name="current" select="."/>
  <xsl:param name="base" select="normalize-space(($current/ancestor-or-self::html:html/html:head/html:base[@href])[1]/@href)"/>
  <xsl:param name="predicate" select="''"/>
  <xsl:param name="object" select="''"/>
  <xsl:param name="prefixes">
    <xsl:apply-templates select="$current" mode="rdfa:prefix-stack"/>
  </xsl:param>
  <xsl:param name="probe" select="false()"/>
  <xsl:param name="debug" select="$rdfa:DEBUG"/>

  <xsl:variable name="resource" select="$object"/>

  <xsl:variable name="bnode-id">
    <xsl:choose>
      <xsl:when test="starts-with($resource, '_:')">
        <xsl:value-of select="substring-after($resource, '_:')"/>
      </xsl:when>
      <xsl:otherwise>&lt;&gt;</xsl:otherwise>
    </xsl:choose>
  </xsl:variable>
  <xsl:variable name="blank-nodes" select="key('rdfa:reverse-node-id', $bnode-id)"/>

  <xsl:variable name="root-resource">
    <xsl:apply-templates select="ancestor-or-self::html:html[1]" mode="rdfa:new-subject">
      <xsl:with-param name="base" select="$base"/>
      <xsl:with-param name="debug" select="$debug"/>
    </xsl:apply-templates>
  </xsl:variable>
  <xsl:if test="$debug">
    <xsl:message>self: <xsl:value-of select="$resource"/> root: <xsl:value-of select="$root-resource"/></xsl:message>
  </xsl:if>

  <!-- okay this is clever -->
  <xsl:variable name="is-root" select="number($root-resource = $resource)"/>
  <xsl:variable name="root-nodes" select="(ancestor-or-self::html:html[$is-root]|ancestor-or-self::html:html[$is-root]/html:head[1]|ancestor-or-self::html:html[$is-root]/html:body[1])[not(@about|@resource|@href|@src)]"/>

  <xsl:variable name="_rel">
    <xsl:call-template name="uri:make-relative-uri">
      <xsl:with-param name="uri" select="$resource"/>
      <xsl:with-param name="base" select="$base"/>
      <xsl:with-param name="strict" select="true()"/>
    </xsl:call-template>
  </xsl:variable>

  <xsl:variable name="resource-rel-strict">
    <xsl:choose>
      <xsl:when test="$_rel != $resource">
        <xsl:value-of select="$_rel"/>
      </xsl:when>
      <xsl:otherwise>&lt;&gt;</xsl:otherwise>
    </xsl:choose>
  </xsl:variable>
  <xsl:variable name="rel-strict-nodes" select="key('rdfa:uri-node', $resource-rel-strict)"/>

  <xsl:variable name="resource-rel-lax">
    <xsl:variable name="_">
      <xsl:call-template name="uri:make-relative-uri">
        <xsl:with-param name="uri" select="$resource"/>
        <xsl:with-param name="base" select="$base"/>
        <xsl:with-param name="strict" select="false()"/>
      </xsl:call-template>
    </xsl:variable>
    <xsl:choose>
      <xsl:when test="$_rel != $resource and $_ != $_rel">
        <xsl:value-of select="$_"/>
      </xsl:when>
      <xsl:otherwise>&lt;&gt;</xsl:otherwise>
    </xsl:choose>
  </xsl:variable>
  <xsl:variable name="rel-lax-nodes" select="key('rdfa:uri-node', $resource-rel-lax)"/>

  <xsl:variable name="resource-rel-full">
    <xsl:choose>
      <xsl:when test="$_rel != $resource">
        <xsl:call-template name="uri:local-part">
          <xsl:with-param name="uri" select="$resource"/>
          <xsl:with-param name="base" select="$base"/>
        </xsl:call-template>
      </xsl:when>
      <xsl:otherwise>&lt;&gt;</xsl:otherwise>
    </xsl:choose>
  </xsl:variable>
  <xsl:variable name="rel-full-nodes" select="key('rdfa:uri-node', $resource-rel-full)"/>

  <xsl:variable name="resource-qs-only">
    <xsl:variable name="_r" select="substring-before($resource, '?')"/>
    <xsl:variable name="_b" select="substring-after($base, $_r)"/>
    <xsl:variable name="_q" select="concat('?', substring-after($resource, '?'))"/>
    <xsl:choose>
      <xsl:when test="contains($resource, '?') and starts-with($base, $_r) and $_rel != $_q and ($_b = '' or starts-with($_b, '?') or starts-with($_b, '#'))">
        <xsl:value-of select="$_q"/>
      </xsl:when>
      <xsl:otherwise>&lt;&gt;</xsl:otherwise>
    </xsl:choose>
  </xsl:variable>
  <xsl:variable name="qs-only-nodes" select="key('rdfa:uri-node', $resource-qs-only)"/>

  <xsl:variable name="resource-curie">
    <xsl:variable name="_">
      <xsl:call-template name="rdfa:make-curie">
        <xsl:with-param name="uri"      select="$resource"/>
        <xsl:with-param name="node"     select="$current"/>
        <xsl:with-param name="prefixes" select="$prefixes"/>
      </xsl:call-template>
    </xsl:variable>
    <xsl:choose>
      <xsl:when test="string-length($_)"><xsl:value-of select="$_"/></xsl:when>
      <xsl:otherwise>&lt;&gt;</xsl:otherwise>
    </xsl:choose>
  </xsl:variable>
  <xsl:variable name="curie-nodes" select="key('rdfa:curie-node', $resource-curie)|key('rdfa:curie-node', concat('[', $resource-curie, ']'))"/>

  <xsl:if test="$debug">
    <xsl:message>NODES: <xsl:copy-of select="count(key('rdfa:uri-node', $resource)|$blank-nodes|$root-nodes|$rel-strict-nodes|$rel-lax-nodes|$rel-full-nodes|$qs-only-nodes|$curie-nodes)"/></xsl:message>
    <xsl:for-each select="key('rdfa:uri-node', $resource)|$blank-nodes|$root-nodes|$rel-strict-nodes|$rel-lax-nodes|$rel-full-nodes|$qs-only-nodes|$curie-nodes">
      <xsl:message>
        <xsl:apply-templates select="." mode="element-dump"/>
      </xsl:message>
    </xsl:for-each>
  </xsl:if>

  <xsl:apply-templates select="key('rdfa:uri-node', $resource)|$blank-nodes|$root-nodes|$rel-strict-nodes|$rel-lax-nodes|$rel-full-nodes|$qs-only-nodes|$curie-nodes" mode="rdfa:object-node">
    <xsl:with-param name="predicate" select="$predicate"/>
    <xsl:with-param name="object" select="$resource"/>
    <xsl:with-param name="base" select="$base"/>
    <xsl:with-param name="probe" select="$probe"/>
    <xsl:with-param name="debug" select="$debug"/>
  </xsl:apply-templates>
</xsl:template>

<x:doc>
  <h3>rdfa:subject-resources</h3>
  <p>this is also part of the interface</p>
</x:doc>

<xsl:template match="html:*" mode="rdfa:subject-resources" name="rdfa:subject-resources">
  <xsl:param name="current"    select="."/>
  <xsl:param name="local-base" select="normalize-space(($current/ancestor-or-self::html:html/html:head/html:base[@href])[1]/@href)"/>
  <xsl:param name="base"       select="$local-base"/>
  <xsl:param name="predicate"  select="''"/>
  <xsl:param name="object"     select="$base"/>
  <xsl:param name="single"     select="false()"/>
  <xsl:param name="raw"        select="false()"/>
  <xsl:param name="traverse"   select="false()"/>
  <xsl:param name="debug"      select="$rdfa:DEBUG"/>
  <xsl:param name="prefixes">
    <xsl:apply-templates select="$current" mode="rdfa:prefix-stack"/>
  </xsl:param>

  <xsl:variable name="resource-list">
    <xsl:choose>
      <xsl:when test="contains(normalize-space($object), ' ')">
        <xsl:call-template name="rdfa:resolve-curie-list">
          <xsl:with-param name="list">
            <xsl:call-template name="str:unique-tokens">
              <xsl:with-param name="string" select="$object"/>
            </xsl:call-template>
          </xsl:with-param>
          <xsl:with-param name="node" select="$current"/>
          <xsl:with-param name="base" select="$base"/>
          <xsl:with-param name="resolve-terms" select="true()"/>
        </xsl:call-template>
      </xsl:when>
      <xsl:otherwise>
        <xsl:call-template name="rdfa:resolve-curie">
          <xsl:with-param name="curie" select="$object"/>
          <xsl:with-param name="node" select="$current"/>
          <xsl:with-param name="base" select="$base"/>
          <xsl:with-param name="resolve-terms" select="true()"/>
        </xsl:call-template>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:variable>

  <xsl:variable name="first-resource">
    <xsl:choose>
      <xsl:when test="contains(normalize-space($resource-list), ' ')">
        <xsl:value-of select="substring-before(normalize-space($resource-list), ' ')"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="normalize-space($resource-list)"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:variable>

  <xsl:if test="$debug">
    <xsl:message>rdfa:subject-resources selecting '<xsl:value-of select="$first-resource"/>' from <xsl:value-of select="$object"/></xsl:message>
  </xsl:if>

  <xsl:variable name="predicate-absolute">
    <xsl:call-template name="rdfa:resolve-curie">
      <xsl:with-param name="curie" select="$predicate"/>
      <xsl:with-param name="node" select="$current"/>
      <xsl:with-param name="base" select="$base"/>
      <xsl:with-param name="resolve-terms" select="true()"/>
    </xsl:call-template>
  </xsl:variable>

  <xsl:if test="$debug">
    <xsl:message>Resolved <xsl:value-of select="$predicate"/> to &lt;<xsl:value-of select="$predicate-absolute"/>&gt;.</xsl:message>
  </xsl:if>

  <xsl:variable name="raw-resource-list">
    <xsl:text> </xsl:text>
    <xsl:if test="$debug">
      <xsl:message>trying rdfa:subject-resource-internal with <xsl:value-of select="$predicate-absolute"/> and <xsl:value-of select="$first-resource"/></xsl:message>
    </xsl:if>

    <xsl:choose>
      <xsl:when test="$traverse">
        <xsl:if test="$debug">
          <xsl:message>rdfa:subject-resources traversing to <xsl:value-of select="$first-resource"/></xsl:message>
        </xsl:if>

	<xsl:variable name="doc">
	  <xsl:call-template name="uri:document-for-uri">
	    <xsl:with-param name="uri" select="$first-resource"/>
	  </xsl:call-template>
	</xsl:variable>
	<xsl:apply-templates select="document($doc)/*" mode="rdfa:subject-resource-internal">
	  <xsl:with-param name="predicate"  select="$predicate-absolute"/>
	  <xsl:with-param name="object"     select="$first-resource"/>
	  <!--<xsl:with-param name="base"       select="$base"/>
	  <xsl:with-param name="prefixes"   select="$prefixes"/>-->
	  <xsl:with-param name="debug"      select="$debug"/>
	</xsl:apply-templates>
      </xsl:when>
      <xsl:otherwise>
	<xsl:apply-templates select="$current" mode="rdfa:subject-resource-internal">
	  <xsl:with-param name="predicate"  select="$predicate-absolute"/>
	  <xsl:with-param name="object"     select="$first-resource"/>
	  <xsl:with-param name="base"       select="$base"/>
	  <xsl:with-param name="prefixes"   select="$prefixes"/>
	  <xsl:with-param name="debug"      select="$debug"/>
	</xsl:apply-templates>
      </xsl:otherwise>
    </xsl:choose>

    <xsl:if test="string-length(substring-after(normalize-space($resource-list), ' '))">
      <xsl:text> </xsl:text>
      <xsl:call-template name="rdfa:subject-resources">
        <xsl:with-param name="predicate" select="$predicate-absolute"/>
        <xsl:with-param name="object"    select="substring-after(normalize-space($resource-list), ' ')"/>
        <xsl:with-param name="current"   select="$current"/>
        <xsl:with-param name="base"      select="$base"/>
        <xsl:with-param name="single"    select="$single"/>
        <xsl:with-param name="traverse"  select="$traverse"/>
        <xsl:with-param name="prefixes"  select="$prefixes"/>
        <xsl:with-param name="debug"     select="$debug"/>
      </xsl:call-template>
    </xsl:if>
  </xsl:variable>

  <xsl:choose>
    <xsl:when test="$raw">
      <xsl:value-of select="$raw-resource-list"/>
    </xsl:when>
    <xsl:when test="$single and contains(normalize-space($raw-resource-list), ' ')">
      <xsl:value-of select="substring-before(normalize-space($raw-resource-list), ' ')"/>
    </xsl:when>
    <xsl:when test="not(contains(normalize-space($raw-resource-list), ' '))">
      <xsl:value-of select="normalize-space($raw-resource-list)"/>
    </xsl:when>
    <xsl:otherwise>
      <xsl:call-template name="str:unique-tokens">
        <xsl:with-param name="string" select="$raw-resource-list"/>
      </xsl:call-template>
    </xsl:otherwise>
  </xsl:choose>

</xsl:template>

<x:doc>
  <h3>rdfa:subjects-for-literal</h3>
</x:doc>

<xsl:template name="rdfa:subjects-for-literal">
  <xsl:param name="current"   select="."/>
  <xsl:param name="base" select="normalize-space(($current/ancestor-or-self::html:html/html:head/html:base[@href])[1]/@href)"/>
  <xsl:param name="predicate" select="''"/>
  <xsl:param name="language"  select="''"/>
  <xsl:param name="datatype"  select="''"/>
  <xsl:param name="value"     select="''"/>
  <xsl:param name="debug"     select="$rdfa:DEBUG"/>

  <xsl:variable name="predicate-absolute">
    <xsl:call-template name="rdfa:resolve-curie">
      <xsl:with-param name="curie" select="$predicate"/>
      <xsl:with-param name="node" select="$current"/>
      <xsl:with-param name="base" select="$base"/>
      <xsl:with-param name="resolve-terms" select="true()"/>
    </xsl:call-template>
  </xsl:variable>

  <xsl:for-each select="key('rdfa:literal-content-node', $value)|
                        key('rdfa:literal-text-node', $value)">
    <xsl:variable name="_">
      <xsl:text> </xsl:text>
      <xsl:choose>
        <xsl:when test="contains(normalize-space(@property), ' ')">
          <xsl:call-template name="rdfa:resolve-curie-list">
            <xsl:with-param name="list">
              <xsl:call-template name="str:unique-tokens">
                <xsl:with-param name="string" select="@property"/>
              </xsl:call-template>
            </xsl:with-param>
            <xsl:with-param name="node" select="."/>
            <xsl:with-param name="base" select="$base"/>
            <xsl:with-param name="resolve-terms" select="true()"/>
          </xsl:call-template>
        </xsl:when>
        <xsl:otherwise>
          <xsl:call-template name="rdfa:resolve-curie">
            <xsl:with-param name="curie" select="@property"/>
            <xsl:with-param name="node" select="."/>
            <xsl:with-param name="base" select="$base"/>
            <xsl:with-param name="resolve-terms" select="true()"/>
          </xsl:call-template>
        </xsl:otherwise>
      </xsl:choose>
      <xsl:text> </xsl:text>
    </xsl:variable>

    <xsl:if test="contains($_, $predicate-absolute)">
      <!--<xsl:message>sup dawg</xsl:message>-->
      <xsl:text> </xsl:text>
      <xsl:apply-templates select="." mode="rdfa:new-subject">
        <xsl:with-param name="base" select="$base"/>
      </xsl:apply-templates>
      <xsl:text> </xsl:text>
    </xsl:if>
  </xsl:for-each>

</xsl:template>

<x:doc>
  <h3>rdfa:literal-subject-node</h3>
</x:doc>

<xsl:template match="html:*|html:*/@*" mode="rdfa:literal-subject-node"/>
<xsl:template match="html:*[not(ancestor::*[@property and not(@content|@datetime)])]|html:*[not(ancestor::*[@property and not(@content|@datetime)])]/@*" mode="rdfa:literal-subject-node">
  <xsl:param name="base" select="normalize-space((ancestor-or-self::html:html/html:head/html:base[@href])[1]/@href)"/>
  <xsl:param name="subject"   select="''"/>
  <xsl:param name="predicate" select="''"/>
  <xsl:param name="language"  select="''"/>
  <xsl:param name="datatype"  select="''"/>
  <xsl:param name="probe" select="false()"/>
  <xsl:param name="debug" select="$rdfa:DEBUG"/>

  <xsl:variable name="element" select="(self::*|..)[last()]"/>

  <xsl:if test="$debug">
  <xsl:message>
    <xsl:text>LITERAL SPO: </xsl:text>
    <xsl:value-of select="$subject"/><xsl:text> </xsl:text>
    <xsl:apply-templates select="$element" mode="element-dump"/>
  </xsl:message>
  </xsl:if>

  <xsl:variable name="is-subject">
    <xsl:apply-templates select="." mode="rdfa:is-subject"/>
  </xsl:variable>
  <xsl:choose>
    <xsl:when test="string-length($is-subject)">
      <!-- descendant-or-self property -->
      <xsl:if test="$debug">
        <xsl:message>LITERAL CALLED WITH SUBJECT <xsl:apply-templates select="$element" mode="element-dump"/></xsl:message>
      </xsl:if>

      <xsl:apply-templates select="$element|$element/*" mode="rdfa:locate-property">
        <xsl:with-param name="predicate" select="$predicate"/>
        <xsl:with-param name="language" select="$language"/>
        <xsl:with-param name="datatype" select="$datatype"/>
        <xsl:with-param name="base" select="$base"/>
        <xsl:with-param name="include-self" select="true()"/>
        <xsl:with-param name="probe" select="$probe"/>
        <xsl:with-param name="debug" select="$debug"/>
      </xsl:apply-templates>
    </xsl:when>
    <xsl:otherwise>
      <!-- descendant property -->
      <xsl:if test="$debug">
        <xsl:message>LITERAL CALLED WITH OBJECT <xsl:apply-templates select="$element" mode="element-dump"/></xsl:message>
      </xsl:if>
      <!--<xsl:apply-templates select="$element/html:*[@rel]|$element/html:*[not(@rel|@rev)][(@property and @content) or not(@property)]|$element/html:*[not(@rel|@rev|@about|@typeof|@resource|@href|@src)][not(@property) or (@property and @content)]" mode="rdfa:locate-property">-->
      <xsl:apply-templates select="$element/html:*" mode="rdfa:locate-property">
        <xsl:with-param name="predicate" select="$predicate"/>
        <xsl:with-param name="language" select="$language"/>
        <xsl:with-param name="datatype" select="$datatype"/>
        <xsl:with-param name="base" select="$base"/>
        <xsl:with-param name="include-self" select="false()"/>
        <xsl:with-param name="probe" select="$probe"/>
        <xsl:with-param name="debug" select="$debug"/>
      </xsl:apply-templates>
    </xsl:otherwise>
  </xsl:choose>

</xsl:template>

<x:doc>
  <h3>rdfa:object-literal-internal</h3>
</x:doc>

<xsl:template match="html:*" mode="rdfa:object-literal-internal">
  <xsl:param name="current" select="."/>
  <xsl:param name="base" select="normalize-space((ancestor-or-self::html:html/html:head/html:base[@href])[1]/@href)"/>
  <xsl:param name="subject"   select="''"/>
  <xsl:param name="predicate" select="''"/>
  <xsl:param name="language"  select="''"/>
  <xsl:param name="datatype"  select="''"/>
  <xsl:param name="prefixes">
    <xsl:apply-templates select="$current" mode="rdfa:prefix-stack"/>
  </xsl:param>
  <xsl:param name="probe" select="false()"/>
  <xsl:param name="debug" select="$rdfa:DEBUG"/>

  <xsl:variable name="resource" select="$subject"/>

    <xsl:variable name="bnode-id">
    <xsl:choose>
      <xsl:when test="starts-with($resource, '_:')">
        <xsl:value-of select="substring-after($resource, '_:')"/>
      </xsl:when>
      <xsl:otherwise>&lt;&gt;</xsl:otherwise>
    </xsl:choose>
  </xsl:variable>
  <xsl:variable name="blank-nodes" select="key('rdfa:reverse-node-id', $bnode-id)"/>

  <xsl:variable name="root-resource">
    <xsl:apply-templates select="ancestor-or-self::html:html[1]" mode="rdfa:new-subject">
      <xsl:with-param name="base" select="$base"/>
      <xsl:with-param name="debug" select="$debug"/>
    </xsl:apply-templates>
  </xsl:variable>
  <xsl:if test="$debug">
    <xsl:message>self: <xsl:value-of select="$resource"/> root: <xsl:value-of select="$root-resource"/></xsl:message>
  </xsl:if>

  <!-- okay this is clever -->
  <xsl:variable name="is-root" select="number($root-resource = $resource)"/>
  <xsl:variable name="root-nodes" select="(ancestor-or-self::html:html[$is-root]|ancestor-or-self::html:html[$is-root]/html:head[1]|ancestor-or-self::html:html[$is-root]/html:body[1])[not(@about|@resource|@href|@src)]"/>

  <xsl:variable name="_rel">
    <xsl:call-template name="uri:make-relative-uri">
      <xsl:with-param name="uri" select="$resource"/>
      <xsl:with-param name="base" select="$base"/>
      <xsl:with-param name="strict" select="true()"/>
    </xsl:call-template>
  </xsl:variable>

  <xsl:variable name="resource-rel-strict">
    <xsl:choose>
      <xsl:when test="$_rel != $resource">
        <xsl:value-of select="$_rel"/>
      </xsl:when>
      <xsl:otherwise>&lt;&gt;</xsl:otherwise>
    </xsl:choose>
  </xsl:variable>
  <xsl:variable name="rel-strict-nodes" select="key('rdfa:uri-node', $resource-rel-strict)"/>

  <xsl:variable name="resource-rel-lax">
    <xsl:variable name="_">
      <xsl:call-template name="uri:make-relative-uri">
        <xsl:with-param name="uri" select="$resource"/>
        <xsl:with-param name="base" select="$base"/>
        <xsl:with-param name="strict" select="false()"/>
      </xsl:call-template>
    </xsl:variable>
    <xsl:choose>
      <xsl:when test="$_rel != $resource and $_ != $_rel">
        <xsl:value-of select="$_"/>
      </xsl:when>
      <xsl:otherwise>&lt;&gt;</xsl:otherwise>
    </xsl:choose>
  </xsl:variable>
  <xsl:variable name="rel-lax-nodes" select="key('rdfa:uri-node', $resource-rel-lax)"/>

  <xsl:variable name="resource-rel-full">
    <xsl:choose>
      <xsl:when test="$_rel != $resource">
        <xsl:call-template name="uri:local-part">
          <xsl:with-param name="uri" select="$resource"/>
          <xsl:with-param name="base" select="$base"/>
        </xsl:call-template>
      </xsl:when>
      <xsl:otherwise>&lt;&gt;</xsl:otherwise>
    </xsl:choose>
  </xsl:variable>
  <xsl:variable name="rel-full-nodes" select="key('rdfa:uri-node', $resource-rel-full)"/>

  <xsl:variable name="resource-qs-only">
    <xsl:variable name="_r" select="substring-before($resource, '?')"/>
    <xsl:variable name="_b" select="substring-after($base, $_r)"/>
    <xsl:variable name="_q" select="concat('?', substring-after($resource, '?'))"/>
    <xsl:choose>
      <xsl:when test="contains($resource, '?') and starts-with($base, $_r) and $_rel != $_q and ($_b = '' or starts-with($_b, '?') or starts-with($_b, '#'))">
        <xsl:value-of select="$_q"/>
      </xsl:when>
      <xsl:otherwise>&lt;&gt;</xsl:otherwise>
    </xsl:choose>
  </xsl:variable>
  <xsl:variable name="qs-only-nodes" select="key('rdfa:uri-node', $resource-qs-only)"/>

  <xsl:variable name="resource-curie">
    <xsl:variable name="_">
      <xsl:call-template name="rdfa:make-curie">
        <xsl:with-param name="uri"      select="$resource"/>
        <xsl:with-param name="node"     select="$current"/>
        <xsl:with-param name="prefixes" select="$prefixes"/>
      </xsl:call-template>
    </xsl:variable>
    <xsl:choose>
      <xsl:when test="string-length($_)"><xsl:value-of select="$_"/></xsl:when>
      <xsl:otherwise>&lt;&gt;</xsl:otherwise>
    </xsl:choose>
  </xsl:variable>

  <xsl:variable name="curie-nodes" select="key('rdfa:curie-node', $resource-curie)|key('rdfa:curie-node', concat('[', $resource-curie, ']'))"/>

  <xsl:if test="$debug">
    <xsl:message>NODES: <xsl:value-of select="count(key('rdfa:uri-node', $resource)|$blank-nodes|$root-nodes|$rel-strict-nodes|$rel-lax-nodes|$rel-full-nodes|$qs-only-nodes|$curie-nodes)"/></xsl:message>
    <xsl:for-each select="key('rdfa:uri-node', $resource)|$blank-nodes|$root-nodes|$rel-strict-nodes|$rel-lax-nodes|$rel-full-nodes|$qs-only-nodes|$curie-nodes">
      <xsl:message>
        <xsl:apply-templates select="." mode="element-dump"/>
      </xsl:message>
    </xsl:for-each>
  </xsl:if>

  <xsl:apply-templates select="key('rdfa:uri-node', $resource)|$blank-nodes|$root-nodes|$rel-strict-nodes|$rel-lax-nodes|$rel-full-nodes|$qs-only-nodes|$curie-nodes" mode="rdfa:literal-subject-node">
    <xsl:with-param name="subject"   select="$resource"/>
    <xsl:with-param name="predicate" select="$predicate"/>
    <xsl:with-param name="language"  select="$language"/>
    <xsl:with-param name="datatype"  select="$datatype"/>
    <xsl:with-param name="base"  select="$base"/>
    <xsl:with-param name="probe" select="$probe"/>
    <xsl:with-param name="debug" select="$debug"/>
  </xsl:apply-templates>
</xsl:template>

<x:doc>
  <h3>rdfa:object-literal-quick</h3>
  <p>this is part of the interface</p>
</x:doc>

<xsl:template match="html:*" mode="rdfa:object-literal-quick" name="rdfa:object-literal-quick">
  <xsl:param name="current"   select="."/>
  <xsl:param name="base" select="normalize-space(($current/ancestor-or-self::html:html/html:head/html:base[@href])[1]/@href)"/>
  <xsl:param name="subject"   select="''"/>
  <xsl:param name="predicate" select="''"/>
  <xsl:param name="language"  select="''"/>
  <xsl:param name="datatype"  select="''"/>
  <xsl:param name="record-sep" select="$rdfa:RECORD-SEP"/>
  <xsl:param name="unit-sep"   select="$rdfa:UNIT-SEP"/>
  <xsl:param name="debug"      select="$rdfa:DEBUG"/>

  <xsl:variable name="predicate-absolute">
    <xsl:call-template name="rdfa:resolve-curie">
      <xsl:with-param name="curie" select="$predicate"/>
      <xsl:with-param name="node" select="$current"/>
      <xsl:with-param name="base" select="$base"/>
    </xsl:call-template>
  </xsl:variable>

  <xsl:if test="$debug">
    <xsl:message>OLQ: <xsl:value-of select="$subject"/><xsl:text> </xsl:text><xsl:value-of select="$predicate-absolute"/> (<xsl:value-of select="$predicate"/>)</xsl:message>
  </xsl:if>

  <xsl:variable name="out">
    <xsl:variable name="_">
    <xsl:apply-templates select="$current" mode="rdfa:object-literal-internal">
      <xsl:with-param name="subject"   select="$subject"/>
      <xsl:with-param name="predicate" select="$predicate-absolute"/>
      <xsl:with-param name="language"  select="$language"/>
      <xsl:with-param name="datatype"  select="$datatype"/>
      <xsl:with-param name="base"      select="$base"/>
      <xsl:with-param name="debug"     select="$debug"/>
    </xsl:apply-templates>
    </xsl:variable>

    <xsl:variable name="esc" select="translate($_, '&#x09;&#x0a;&#x0d;&#x20;', '&#xf109;&#xf10a;&#xf10d;&#xf120;')"/>
    <xsl:variable name="prune" select="normalize-space(translate($esc, $record-sep, ' '))"/>
    <xsl:if test="string-length($prune)">
      <xsl:variable name="first">
        <xsl:choose>
          <xsl:when test="contains($prune, ' ')">
            <xsl:value-of select="substring-before($prune, ' ')"/>
          </xsl:when>
          <xsl:otherwise><xsl:value-of select="$prune"/></xsl:otherwise>
        </xsl:choose>
      </xsl:variable>

      <xsl:value-of select="translate($first, '&#xf109;&#xf10a;&#xf10d;&#xf120;', '&#x09;&#x0a;&#x0d;&#x20;')"/>
    </xsl:if>
  </xsl:variable>

  <xsl:value-of select="$out"/>

</xsl:template>

<x:doc>
  <h3>rdfa:object-literals</h3>
  <p>this is part of the interface</p>
</x:doc>

<xsl:template match="html:*" mode="rdfa:object-literals" name="rdfa:object-literals">
  <xsl:param name="current"   select="."/>
  <xsl:param name="base"      select="normalize-space(($current/ancestor-or-self::html:html/html:head/html:base[@href])[1]/@href)"/>
  <xsl:param name="subject"   select="''"/>
  <xsl:param name="predicate" select="''"/>
  <xsl:param name="language"  select="''"/>
  <xsl:param name="datatype"  select="''"/>
  <xsl:param name="sanitize"  select="true()"/>
  <xsl:param name="prune"     select="true()"/>
  <xsl:param name="record-sep" select="$rdfa:RECORD-SEP"/>
  <xsl:param name="unit-sep"   select="$rdfa:UNIT-SEP"/>
  <xsl:param name="debug"      select="$rdfa:DEBUG"/>

  <xsl:variable name="resource-list">
    <xsl:choose>
      <xsl:when test="$sanitize and contains(normalize-space($subject), ' ')">
        <xsl:call-template name="rdfa:resolve-curie-list">
          <xsl:with-param name="list">
            <xsl:call-template name="str:unique-tokens">
              <xsl:with-param name="string" select="$subject"/>
            </xsl:call-template>
          </xsl:with-param>
          <xsl:with-param name="node" select="$current"/>
          <xsl:with-param name="base" select="$base"/>
          <xsl:with-param name="resolve-terms" select="true()"/>
        </xsl:call-template>
      </xsl:when>
      <xsl:when test="$sanitize">
        <xsl:call-template name="rdfa:resolve-curie">
          <xsl:with-param name="curie" select="$subject"/>
          <xsl:with-param name="node" select="$current"/>
          <xsl:with-param name="base" select="$base"/>
          <xsl:with-param name="resolve-terms" select="true()"/>
        </xsl:call-template>
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="normalize-space($subject)"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:variable>

  <xsl:if test="$debug">
    <xsl:message>rdfa:object-literals: handling resource list <xsl:value-of select="$resource-list"/></xsl:message>
  </xsl:if>

  <xsl:variable name="first-resource">
    <xsl:choose>
      <xsl:when test="contains(normalize-space($resource-list), ' ')">
        <xsl:value-of select="substring-before(normalize-space($resource-list), ' ')"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="normalize-space($resource-list)"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:variable>

  <xsl:variable name="predicate-absolute">
    <xsl:choose>
      <xsl:when test="$sanitize">
        <xsl:call-template name="rdfa:resolve-curie">
          <xsl:with-param name="curie" select="$predicate"/>
          <xsl:with-param name="node" select="$current"/>
          <xsl:with-param name="base" select="$base"/>
          <xsl:with-param name="resolve-terms" select="true()"/>
        </xsl:call-template>
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="normalize-space($predicate)"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:variable>

  <xsl:if test="$debug">
    <xsl:message><xsl:value-of select="$predicate"/> resolved to <xsl:value-of select="$predicate-absolute"/></xsl:message>
  </xsl:if>

  <xsl:variable name="datatype-absolute">
    <xsl:choose>
      <xsl:when test="$sanitize and string-length(normalize-space($datatype))">
        <xsl:call-template name="rdfa:resolve-curie">
          <xsl:with-param name="curie" select="$datatype"/>
          <xsl:with-param name="node" select="$current"/>
          <xsl:with-param name="base" select="$base"/>
          <xsl:with-param name="resolve-terms" select="true()"/>
        </xsl:call-template>
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="normalize-space($datatype)"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:variable>

  <xsl:variable name="raw-output">
    <!--<xsl:value-of select="$record-sep"/>-->
    <xsl:if test="$debug">
      <xsl:message>rdfa:object-literals: processing <xsl:value-of select="$first-resource"/></xsl:message>
    </xsl:if>

    <xsl:apply-templates select="$current" mode="rdfa:object-literal-internal">
      <xsl:with-param name="subject"   select="$first-resource"/>
      <xsl:with-param name="predicate" select="$predicate-absolute"/>
      <xsl:with-param name="language"  select="$language"/>
      <xsl:with-param name="datatype"  select="$datatype-absolute"/>
      <xsl:with-param name="base"      select="$base"/>
      <xsl:with-param name="debug"     select="$debug"/>
    </xsl:apply-templates>

    <xsl:if test="contains(normalize-space($resource-list), ' ')">
      <xsl:value-of select="$record-sep"/>
      <xsl:apply-templates select="$current" mode="rdfa:object-literals">
        <xsl:with-param name="subject"   select="substring-after(normalize-space($resource-list), ' ')"/>
        <xsl:with-param name="predicate" select="$predicate-absolute"/>
        <xsl:with-param name="language"  select="$language"/>
        <xsl:with-param name="datatype"  select="$datatype-absolute"/>
        <xsl:with-param name="base"      select="$base"/>
        <xsl:with-param name="current"   select="$current"/>
        <xsl:with-param name="sanitize"  select="false()"/>
        <xsl:with-param name="prune"     select="false()"/>
        <xsl:with-param name="debug"     select="$debug"/>
      </xsl:apply-templates>
    </xsl:if>

    <!--<xsl:value-of select="$record-sep"/>-->
  </xsl:variable>

  <xsl:choose>
    <xsl:when test="$prune">
      <xsl:call-template name="str:unique-strings">
        <xsl:with-param name="string" select="$raw-output"/>
      </xsl:call-template>
    </xsl:when>
    <xsl:otherwise><xsl:value-of select="$raw-output"/></xsl:otherwise>
  </xsl:choose>

</xsl:template>

<x:doc>
  <h3>rdfa:coded-objects</h3>
  <p>no idea what this was supposed to be</p>
</x:doc>

<xsl:template name="rdfa:coded-objects">
</xsl:template>

<x:doc>
  <h3>rdfa:has-predicate</h3>
</x:doc>

<xsl:template name="rdfa:has-predicate">
  <xsl:param name="base" select="normalize-space((/html:html/html:head/html:base[@href])[1]/@href)"/>
  <xsl:param name="current"   select="."/>
  <xsl:param name="subject"   select="''"/>
  <xsl:param name="predicate" select="''"/>
  <xsl:param name="object"   select="''"/>

  <xsl:if test="string-length(normalize-space($subject))
                and string-length(normalize-space($object))">
    <xsl:message terminate="yes">Cannot have both a subject and an object</xsl:message>
  </xsl:if>

  <xsl:variable name="predicate-absolute">
    <xsl:call-template name="rdfa:resolve-curie">
      <xsl:with-param name="curie" select="$predicate"/>
      <xsl:with-param name="node" select="$current"/>
      <xsl:with-param name="base" select="$base"/>
      <xsl:with-param name="resolve-terms" select="true()"/>
    </xsl:call-template>
  </xsl:variable>

  <xsl:variable name="out">
  <xsl:choose>
    <xsl:when test="string-length(normalize-space($subject))">

      <xsl:variable name="resource-list">
        <xsl:choose>
          <xsl:when test="contains(normalize-space($subject), ' ')">
            <xsl:call-template name="rdfa:resolve-curie-list">
              <xsl:with-param name="list">
                <xsl:call-template name="str:unique-tokens">
                  <xsl:with-param name="string" select="$subject"/>
                </xsl:call-template>
              </xsl:with-param>
              <xsl:with-param name="node" select="$current"/>
              <xsl:with-param name="base" select="$base"/>
              <xsl:with-param name="resolve-terms" select="true()"/>
            </xsl:call-template>
          </xsl:when>
          <xsl:otherwise>
            <xsl:call-template name="rdfa:resolve-curie">
              <xsl:with-param name="curie" select="$subject"/>
              <xsl:with-param name="node" select="$current"/>
              <xsl:with-param name="base" select="$base"/>
              <xsl:with-param name="resolve-terms" select="true()"/>
            </xsl:call-template>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:variable>

      <xsl:variable name="first-resource">
        <xsl:choose>
          <xsl:when test="contains(normalize-space($resource-list), ' ')">
            <xsl:value-of select="substring-before(normalize-space($resource-list), ' ')"/>
          </xsl:when>
          <xsl:otherwise>
            <xsl:value-of select="normalize-space($resource-list)"/>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:variable>

      <xsl:variable name="test">
        <xsl:apply-templates select="$current" mode="rdfa:object-resource-internal">
          <xsl:with-param name="subject"   select="$first-resource"/>
          <xsl:with-param name="predicate" select="$predicate-absolute"/>
          <xsl:with-param name="base"  select="$base"/>
          <xsl:with-param name="probe" select="true()"/>
        </xsl:apply-templates>
        <xsl:apply-templates select="$current" mode="rdfa:object-literal-internal">
          <xsl:with-param name="subject"   select="$first-resource"/>
          <xsl:with-param name="predicate" select="$predicate-absolute"/>
          <xsl:with-param name="base"  select="$base"/>
          <xsl:with-param name="probe" select="true()"/>
        </xsl:apply-templates>
      </xsl:variable>

      <!--<xsl:message><xsl:value-of select="$first-resource"/> has '<xsl:value-of select="$test"/>'</xsl:message>-->

      <xsl:if test="string-length(normalize-space($test))">
        <xsl:value-of select="concat(' ', $first-resource, ' ')"/>
      </xsl:if>

      <xsl:if test="string-length(substring-after(normalize-space($resource-list), ' '))">
        <xsl:call-template name="rdfa:has-predicate">
          <xsl:with-param name="subject" select="substring-after(normalize-space($resource-list), ' ')"/>
          <xsl:with-param name="predicate" select="$predicate-absolute"/>
          <xsl:with-param name="base" select="$base"/>
        </xsl:call-template>
      </xsl:if>

    </xsl:when>
    <xsl:when test="string-length(normalize-space($object))">

      <xsl:variable name="resource-list">
        <xsl:choose>
          <xsl:when test="contains(normalize-space($object), ' ')">
            <xsl:call-template name="rdfa:resolve-curie-list">
              <xsl:with-param name="list">
                <xsl:call-template name="str:unique-tokens">
                  <xsl:with-param name="string" select="$object"/>
                </xsl:call-template>
              </xsl:with-param>
              <xsl:with-param name="node" select="$current"/>
              <xsl:with-param name="base" select="$base"/>
              <xsl:with-param name="resolve-terms" select="true()"/>
            </xsl:call-template>
          </xsl:when>
          <xsl:otherwise>
            <xsl:call-template name="rdfa:resolve-curie">
              <xsl:with-param name="curie" select="$object"/>
              <xsl:with-param name="node" select="$current"/>
              <xsl:with-param name="base" select="$base"/>
              <xsl:with-param name="resolve-terms" select="true()"/>
            </xsl:call-template>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:variable>

      <xsl:variable name="first-resource">
        <xsl:choose>
          <xsl:when test="contains(normalize-space($resource-list), ' ')">
            <xsl:value-of select="substring-before(normalize-space($resource-list), ' ')"/>
          </xsl:when>
          <xsl:otherwise>
            <xsl:value-of select="normalize-space($resource-list)"/>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:variable>

    </xsl:when>
    <xsl:otherwise/>
  </xsl:choose>
  </xsl:variable>

  <xsl:call-template name="str:unique-tokens">
    <xsl:with-param name="string" select="$out"/>
  </xsl:call-template>

</xsl:template>

<x:doc>
  <h3>rdfa:get-subject</h3>
  <p>you give this a node and it tells you the subject</p>
  <p>this is part of the interface</p>
</x:doc>

<xsl:template match="html:*[ancestor::*[@property][not(@content|@datetime)]]" mode="rdfa:get-subject" priority="10">
  <xsl:message>hit <xsl:value-of select="name()"/></xsl:message>
</xsl:template>

<xsl:template match="html:*[@about]" mode="rdfa:get-subject" priority="5">
  <xsl:param name="base" select="normalize-space((/html:html/html:head/html:base[@href])[1]/@href)"/>
  <xsl:param name="debug" select="$rdfa:DEBUG"/>
  <xsl:if test="$debug">
    <xsl:message>Found @about <xsl:value-of select="@about"/></xsl:message>
  </xsl:if>
  <xsl:call-template name="rdfa:resolve-curie">
    <xsl:with-param name="curie" select="@about"/>
    <xsl:with-param name="base" select="$base"/>
  </xsl:call-template>
</xsl:template>

<xsl:template match="html:*[@resource][not(@about)]" mode="rdfa:get-subject" priority="4.5">
  <xsl:param name="base" select="normalize-space((/html:html/html:head/html:base[@href])[1]/@href)"/>
  <xsl:param name="debug" select="$rdfa:DEBUG"/>
  <xsl:if test="$debug">
    <xsl:message>Found @resource <xsl:value-of select="@resource"/></xsl:message>
  </xsl:if>
  <xsl:call-template name="rdfa:resolve-curie">
    <xsl:with-param name="curie" select="@resource"/>
    <xsl:with-param name="base" select="$base"/>
  </xsl:call-template>
</xsl:template>

<xsl:template match="html:*[@href][not(@about|@resource)]" mode="rdfa:get-subject" priority="4">
  <xsl:param name="base" select="normalize-space((/html:html/html:head/html:base[@href])[1]/@href)"/>
  <xsl:param name="debug" select="$rdfa:DEBUG"/>
  <xsl:if test="$debug">
    <xsl:message>Found @href <xsl:value-of select="@href"/></xsl:message>
  </xsl:if>
  <xsl:call-template name="uri:make-absolute-uri">
    <xsl:with-param name="uri" select="@href"/>
    <xsl:with-param name="base" select="$base"/>
  </xsl:call-template>
</xsl:template>

<xsl:template match="html:*[@src][not(@about|@resource|@href)]" mode="rdfa:get-subject" priority="3.5">
  <xsl:param name="base" select="normalize-space((/html:html/html:head/html:base[@href])[1]/@href)"/>
  <xsl:param name="debug" select="$rdfa:DEBUG"/>
  <xsl:if test="$debug">
    <xsl:message>Found @src <xsl:value-of select="@src"/></xsl:message>
  </xsl:if>
  <xsl:call-template name="uri:make-absolute-uri">
    <xsl:with-param name="uri" select="@src"/>
    <xsl:with-param name="base" select="$base"/>
  </xsl:call-template>
</xsl:template>

<xsl:template match="html:*[@typeof][not(@about|@resource|@href|@src)]" mode="rdfa:get-subject" priority="3">
  <xsl:param name="debug" select="$rdfa:DEBUG"/>
  <xsl:if test="$debug">
    <xsl:message>Found blank node <xsl:value-of select="generate-id(.)"/></xsl:message>
  </xsl:if>
  <xsl:value-of select="concat('_:', generate-id(.))"/>
</xsl:template>

<xsl:template match="html:head[not(@about|@resource|@href|@src)]|html:body[not(@about|@resource|@href|@src)]" mode="rdfa:get-subject" priority="5">
  <xsl:param name="base" select="normalize-space((/html:html/html:head/html:base[@href])[1]/@href)"/>
  <xsl:param name="debug" select="$rdfa:DEBUG"/>
  <xsl:if test="$debug">
    <xsl:message>Special case for head/body</xsl:message>
  </xsl:if>
  <xsl:apply-templates select="parent::html:*" mode="rdfa:_get-subject-up">
    <xsl:with-param name="base" select="$base"/>
    <xsl:with-param name="debug" select="$debug"/>
  </xsl:apply-templates>
</xsl:template>

<xsl:template match="html:*[not(parent::html:*)][not(@about|@resource|@href|@src)]" mode="rdfa:get-subject" priority="5">
  <xsl:param name="base" select="normalize-space((/html:html/html:head/html:base[@href])[1]/@href)"/>
  <xsl:param name="debug" select="$rdfa:DEBUG"/>
  <xsl:if test="$debug">
    <xsl:message>Special case for root element</xsl:message>
  </xsl:if>
  <xsl:value-of select="$base"/>
</xsl:template>

<xsl:template match="html:*[not(@about|@typeof|@resource|@href|@src)]" mode="rdfa:get-subject">
  <xsl:param name="base" select="normalize-space((/html:html/html:head/html:base[@href])[1]/@href)"/>
  <xsl:param name="debug" select="$rdfa:DEBUG"/>
  <xsl:if test="$debug">
    <xsl:message>Searching parent element (<xsl:value-of select="name(parent::html:*)"/>) for RDF</xsl:message>
  </xsl:if>
  <xsl:apply-templates select="parent::html:*" mode="rdfa:_get-subject-up">
    <xsl:with-param name="base" select="$base"/>
    <xsl:with-param name="debug" select="$debug"/>
  </xsl:apply-templates>
</xsl:template>

<x:doc>
  <h3>rdfa:_get-subject-up</h3>
  <p>now ascending</p>
</x:doc>

<xsl:template match="html:*[not(@about|@typeof|@resource|@href|@src)]" mode="rdfa:_get-subject-up">
  <xsl:param name="base" select="normalize-space((/html:html/html:head/html:base[@href])[1]/@href)"/>
  <xsl:param name="debug" select="$rdfa:DEBUG"/>
  <xsl:if test="$debug">
    <xsl:message>searching parent element (<xsl:value-of select="name(parent::html:*)"/>) for RDF</xsl:message>
  </xsl:if>
  <xsl:apply-templates select="parent::html:*" mode="rdfa:_get-subject-up">
    <xsl:with-param name="base" select="$base"/>
    <xsl:with-param name="debug" select="$debug"/>
  </xsl:apply-templates>
</xsl:template>

<xsl:template match="html:*[@resource]" mode="rdfa:_get-subject-up" priority="5">
  <xsl:param name="base" select="normalize-space((/html:html/html:head/html:base[@href])[1]/@href)"/>
  <xsl:param name="debug" select="$rdfa:DEBUG"/>
  <xsl:if test="$debug">
    <xsl:message>Found @resource (ascending) <xsl:value-of select="@resource"/></xsl:message>
  </xsl:if>
  <xsl:call-template name="rdfa:resolve-curie">
    <xsl:with-param name="curie" select="@resource"/>
    <xsl:with-param name="base" select="$base"/>
  </xsl:call-template>
</xsl:template>

<xsl:template match="html:*[@href][not(@resource)]" mode="rdfa:_get-subject-up" priority="4.5">
  <xsl:param name="base" select="normalize-space((/html:html/html:head/html:base[@href])[1]/@href)"/>
  <xsl:param name="debug" select="$rdfa:DEBUG"/>
  <xsl:if test="$debug">
    <xsl:message>Found @href (ascending) <xsl:value-of select="@href"/></xsl:message>
  </xsl:if>
  <xsl:call-template name="uri:make-absolute-uri">
    <xsl:with-param name="uri" select="@href"/>
    <xsl:with-param name="base" select="$base"/>
  </xsl:call-template>
</xsl:template>

<xsl:template match="html:*[@src][not(@resource|@href)]" mode="rdfa:_get-subject-up" priority="4">
  <xsl:param name="base" select="normalize-space((/html:html/html:head/html:base[@href])[1]/@href)"/>
  <xsl:param name="debug" select="$rdfa:DEBUG"/>
  <xsl:if test="$debug">
    <xsl:message>Found @src (ascending) <xsl:value-of select="@src"/></xsl:message>
  </xsl:if>
  <xsl:call-template name="uri:make-absolute-uri">
    <xsl:with-param name="uri" select="@src"/>
    <xsl:with-param name="base" select="$base"/>
  </xsl:call-template>
</xsl:template>

<xsl:template match="html:*[@about][not(@resource|@href|@src)]" mode="rdfa:_get-subject-up" priority="3.5">
  <xsl:param name="base" select="normalize-space((/html:html/html:head/html:base[@href])[1]/@href)"/>
  <xsl:param name="debug" select="$rdfa:DEBUG"/>
  <xsl:if test="$debug">
    <xsl:message>Found @about (ascending) <xsl:value-of select="@about"/></xsl:message>
  </xsl:if>
  <xsl:call-template name="rdfa:resolve-curie">
    <xsl:with-param name="curie" select="@about"/>
    <xsl:with-param name="base" select="$base"/>
  </xsl:call-template>
</xsl:template>

<xsl:template match="html:head[not(@about|@resource|@href|@src)]|html:body[not(@about|@resource|@href|@src)]" mode="rdfa:_get-subject-up" priority="5">
  <xsl:param name="base" select="normalize-space((/html:html/html:head/html:base[@href])[1]/@href)"/>
  <xsl:param name="debug" select="$rdfa:DEBUG"/>
  <xsl:if test="$debug">
    <xsl:message>Special case for head/body</xsl:message>
  </xsl:if>
  <xsl:apply-templates select="parent::html:*" mode="rdfa:_get-subject-up">
    <xsl:with-param name="base" select="$base"/>
    <xsl:with-param name="debug" select="$debug"/>
  </xsl:apply-templates>
</xsl:template>

<xsl:template match="html:*[not(parent::html:*)][not(@about|@resource|@href|@src)]" mode="rdfa:_get-subject-up" priority="5">
  <xsl:param name="base" select="normalize-space((/html:html/html:head/html:base[@href])[1]/@href)"/>
  <xsl:param name="debug" select="$rdfa:DEBUG"/>
  <xsl:if test="$debug">
    <xsl:message>Special case for root element</xsl:message>
  </xsl:if>
  <xsl:value-of select="$base"/>
</xsl:template>

<xsl:template match="html:*[@typeof][not(@about|@resource|@href|@src)]" mode="rdfa:_get-subject-up">
  <xsl:value-of select="concat('_:', generate-id(.))"/>
</xsl:template>

</xsl:stylesheet>
