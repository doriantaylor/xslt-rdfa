<?xml version="1.0" encoding="utf-8"?>
<xsl:stylesheet version="1.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:html="http://www.w3.org/1999/xhtml"
                xmlns:uri="http://xsltsl.org/uri"
                xmlns:str="http://xsltsl.org/string"
                xmlns:rdfa="https://www.w3.org/ns/rdfa#"
                xmlns="http://www.w3.org/1999/xhtml"
                exclude-result-prefixes="html uri str rdfa">

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

<xsl:import href="xsltsl/uri"/>
<xsl:import href="xsltsl/string"/>

<!-- ### HERE IS A CRAPLOAD OF KEYS ### -->

<!--<xsl:key name="rdfa:interesting-nodes" match="html:html|html:html/html:head|html:html/html:body|html:*[@about|@typeof|@resource|@href|@src|@rel|@rev|@property]|html:*[@about|@typeof|@resource|@href|@src|@rel|@rev|@property]/@*" use="''"/>-->

<xsl:key name="rdfa:reverse-node-id" match="html:html|html:head|html:body|html:*[@about|@typeof|@resource|@href|@src|@rel|@rev|@property|@inlist]|html:*[@about|@typeof|@resource|@href|@src|@rel|@rev|@property|@inlist]/@*" use="generate-id(.)"/>

<!--<xsl:key name="rdfa:has-typeof" match="html:*[@typeof]" use="''"/>-->
<!--<xsl:key name="rdfa:has-uri" match="html:*[@about]|html:*[@resource]|html:*[@href and not(@resource)]|html:*[@src and not(@href|@resource)]" use="''"/>-->
<!--<xsl:key name="rdfa:uri-node" match="html:*[@about|@resource|@href|@src]" use="@about|@resource|@href|@src"/>-->
<!--<xsl:key name="rdfa:resource-node" match="html:*[@about]|html:*[@resource]|html:*[@href][not(@resource)]|html:*[@src][not(@href|@resource)]" use="@about|@resource|@href|@src"/>-->

<!--<xsl:key name="rdfa:source-node" match="html:*[@about]/@about" use="normalize-space(.)"/>-->
<!--<xsl:key name="rdfa:target-node" match="html:*[@resource]/@resource|html:*[@href][not(@resource)]/@href|html:*[@src][not(@resource or @href)]/@src" use="normalize-space(.)"/>-->

<!--<xsl:key name="rdfa:curie-node" match="html:*[@about]/@about|html:*[@resource]/@resource" use="normalize-space(.)"/>-->
<!--<xsl:key name="rdfa:uri-node" match="html:*[@about]/@about|html:*[@resource]/@resource|html:*[@href][not(@resource)]/@href|html:*[@src][not(@resource|@href)]/@src" use="normalize-space(.)"/>-->

<xsl:key name="rdfa:curie-node" match="html:*[@about][not(ancestor::*[@property and not(@content)])]/@about|html:*[@resource][not(ancestor::*[@property and not(@content)])]/@resource" use="normalize-space(.)"/>

<xsl:key name="rdfa:uri-node" match="html:*[@about][not(ancestor::*[@property and not(@content)])]/@about|html:*[@resource][not(ancestor::*[@property and not(@content)])]/@resource|html:*[@href][not(@resource)][not(ancestor::*[@property and not(@content)])]/@href|html:*[@src][not(@resource|@href)][not(ancestor::*[@property and not(@content)])]/@src" use="normalize-space(.)"/>

<xsl:key name="rdfa:literal-content-node" match="html:*[@property][@content]" use="@content"/>
<xsl:key name="rdfa:literal-text-node" match="html:*[@property][not(@content)][@rel|@rev or not((@typeof and not(@about)) or @resource|@href|@src)]" use="string(.)"/>

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
<xsl:variable name="DEBUG" select="false()"/>
<xsl:variable name="RDF-NS" select="'http://www.w3.org/1999/02/22-rdf-syntax-ns#'"/>


<!--
    ### THIS IS ALL STUFF THAT SHOULD REALLY BE INCORPORATED INTO XSLTSL ###
-->

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

<!--
    this is a temporary solution to deal with shortcomings in
    uri:resolve-uri
-->

<xsl:template name="uri:resolve-uri">
  <xsl:param name="uri"/>
  <xsl:param name="reference" select="$uri"/>
  <xsl:param name="base"/>
  <xsl:param name="document" select="$base"/>

  <!--
  <xsl:message>the good one being called on <xsl:value-of select="$reference"/></xsl:message>
  -->

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

  <xsl:choose>
    <xsl:when test="string-length($reference-scheme)">
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

<xsl:template name="uri:make-relative-uri">
  <xsl:param name="uri" select="''"/>
  <xsl:param name="base" select="''"/>
  <xsl:param name="strict" select="false()"/>

  <!--
  <xsl:variable name="_b" select="normalize-space($base)"/>
  <xsl:variable name="_u" select="normalize-space($uri)"/>

  <xsl:if test="$_b != translate($_b, ' ', '')">
    <xsl:message terminate="yes">uri:make-relative-uri: Found whitespace in base URI</xsl:message>
  </xsl:if>

  <xsl:if test="$_u != translate($_u, ' ', '')">
    <xsl:message terminate="yes">uri:make-relative-uri: Found whitespace in URI</xsl:message>
  </xsl:if>

  <xsl:if test="string-length($_b) = 0">
    <xsl:message terminate="yes">uri:make-relative-uri: Base URI is empty</xsl:message>
  </xsl:if>
  -->

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

<!-- deduplicate tokens -->

<xsl:template name="str:unique-tokens">
  <xsl:param name="string"/>
  <xsl:param name="cache"/>

  <!-- normalize input -->
  <xsl:variable name="_ns" select="normalize-space($string)"/>

  <xsl:choose>
    <xsl:when test="contains($_ns, ' ')">
      <xsl:variable name="in" select="substring-before($_ns, ' ')"/>

      <xsl:variable name="out">
        <xsl:choose>
          <xsl:when test="contains(concat(' ', $cache, ' '), concat(' ', $in, ' '))">
            <xsl:value-of select="$cache"/>
          </xsl:when>
          <xsl:otherwise>
            <xsl:value-of select="concat($cache, ' ', $in)"/>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:variable>

      <xsl:variable name="rest" select="substring-after($_ns, ' ')"/>
      <xsl:choose>
        <xsl:when test="contains($rest, ' ')">
          <xsl:call-template name="str:unique-tokens">
            <xsl:with-param name="string" select="$rest"/>
            <xsl:with-param name="cache" select="$out"/>
          </xsl:call-template>
        </xsl:when>
        <xsl:when test="contains(concat(' ', $cache, ' '), concat(' ', $rest, ' '))">
          <xsl:value-of select="normalize-space($out)"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="normalize-space(concat($out, ' ', $rest))"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:when>
    <xsl:when test="string-length($_ns) != 0">
      <xsl:choose>
        <xsl:when test="contains(concat(' ', $cache, ' '), concat(' ', $_ns, ' '))">
          <xsl:value-of select="normalize-space($cache)"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="concat($cache, ' ', $_ns)"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:when>
    <xsl:otherwise><xsl:value-of select="normalize-space($cache)"/></xsl:otherwise>
  </xsl:choose>

</xsl:template>


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
      2) translate() a particular delimeter into spaces and run
         normalize-space() to prune out empty records
      3) translate() the delimiter back to its original counterpart
      4) translate() whitespace chars back to their originals too

      NOTE actually we're using the range U+F100
  -->

<xsl:template name="str:unique-strings">
  <xsl:param name="string" select="''"/>
  <xsl:param name="delimiter" select="'&#xf11e;'"/>

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

<!-- ### RDFA STUFF ### -->

<xsl:template match="html:*" mode="rdfa:prefix-stack">
  <xsl:variable name="prefix" select="normalize-space(@prefix)"/>
  <xsl:if test="string-length($prefix) != 0">
    <xsl:value-of select="concat(' ', $prefix, ' ')"/>
  </xsl:if>
  <xsl:apply-templates select="parent::html:*" mode="rdfa:prefix-stack"/>
</xsl:template>

<!-- Resolve a CURIE -->

<xsl:template name="rdfa:resolve-curie">
<xsl:param name="curie" select="''"/>
<xsl:param name="node" select="."/>
<xsl:param name="base"/>

<xsl:variable name="prefixes">
  <xsl:apply-templates select="$node" mode="rdfa:prefix-stack"/>
</xsl:variable>

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

<xsl:choose>
  <xsl:when test="contains($content, ':')">
    <xsl:variable name="prefix" select="substring-before($content, ':')"/>
    <xsl:variable name="slug" select="substring-after($content, ':')"/>
    <xsl:variable name="ns" select="substring-before(substring-after($prefixes, concat(' ', $prefix, ': ')), ' ')"/>
    <xsl:choose>
      <xsl:when test="string-length($ns) != 0">
        <xsl:value-of select="concat($ns, $slug)"/>
      </xsl:when>
      <xsl:otherwise><xsl:value-of select="$content"/></xsl:otherwise>
    </xsl:choose>
  </xsl:when>
  <xsl:when test="$node/ancestor-or-self::html:*[@vocab] and string-length($content) != 0">
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

<xsl:template name="rdfa:resolve-curie-list">
  <xsl:param name="list"/>
  <xsl:param name="node" select="."/>
  <xsl:param name="base"/>

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
    </xsl:call-template>

    <xsl:variable name="rest" select="substring-after($str, ' ')"/>

    <xsl:if test="string-length($rest) != 0">
      <xsl:text> </xsl:text>
      <xsl:call-template name="rdfa:resolve-curie-list">
        <xsl:with-param name="list" select="$rest"/>
        <xsl:with-param name="node" select="$node"/>
        <xsl:with-param name="base" select="$base"/>
      </xsl:call-template>
    </xsl:if>
  </xsl:if>

</xsl:template>

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


<!--<xsl:template name="rdfa:get-subjects"/>-->

<!--
    * pass in a subject URI
    * returns a space-separated string of URIs
    * current node as optional parameter
-->

<xsl:template name="rdfa:predicates-for-subject">
  <xsl:param name="subject" select="''"/>
  <xsl:param name="current" select="."/>
</xsl:template>

<!--
    if subject is empty then only top of the tree or anything with
    about
-->

<xsl:template name="rdfa:subjects-for-predicate">
  <xsl:param name="predicate" select="''"/>
  <xsl:param name="current" select="."/>
</xsl:template>

<!--
    ascending will probably look something like:

    self::*[@about|@typeof] and stop.
    ancestor::*[@about|@typeof|@resource|@href|@src][1]

    descending like:

    self::*[@resource|@href|@src] and stop.
    otherwise descendant::*[@about|@typeof|

-->

<xsl:template match="html:*[not(@rel|@rev)][@property][not(@content|@datatype)]" mode="rdfa:new-subject">
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

<xsl:template match="html:*[not(@rel|@rev)][@property][not(@content|@datatype)][@typeof]" mode="rdfa:current-object-resource">
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

<xsl:template match="html:*" mode="rdfa:skip-element"/>
<xsl:template match="html:*[not(@rel|@rev|@about|@resource|@href|@src|@typeof|@property)]" mode="rdfa:skip-element">
<!-- will get stringified but alternative is empty ergo false so whatev -->
<xsl:value-of select="true()"/>
</xsl:template>

<!-- we have an attribute or element, and we want to know if it is a
     subject or object -->
<xsl:template match="html:*|html:*/@*" mode="rdfa:is-subject"/>
<xsl:template match="html:*/@about|
                     html:*[not(@rel|@rev|@about)][not(@property) or (@property and @content|@datatype)]/@resource|
                     html:*[not(@rel|@rev|@about|@resource)][not(@property) or (@property and @content|@datatype)]/@href|
                     html:*[not(@rel|@rev|@about|@resource|@href)][not(@property) or (@property and @content|@datatype)]/@src|
                     html:*[@typeof][not(@about|@rel|@rev)][not(@property) or (@property and @content|@datatype)]|
                     html:body|html:head|html:html" mode="rdfa:is-subject">
  <xsl:value-of select="true()"/>
</xsl:template>

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
  </xsl:call-template>
</xsl:template>

<xsl:template match="html:*|html:*/@*" mode="element-dump">
  <xsl:variable name="element" select="(self::*|..)[last()]"/>
  <xsl:text>&lt;</xsl:text><xsl:value-of select="name($element)"/>
  <xsl:for-each select="$element/@*">
    <xsl:value-of select="concat(' ', name(), '=&quot;', ., '&quot;')"/>
    </xsl:for-each><xsl:text>&gt;</xsl:text>
</xsl:template>

<!-- WHAT WE WERE ORIGINALLY WORKING ON -->

<xsl:template match="*|@*" mode="rdfa:resource-down">
  <xsl:message terminate="yes">THIS SHOULD NEVER GET RUN</xsl:message>
</xsl:template>

<xsl:template match="html:*[not(@rel|@rev|@about|@typeof|@resource|@href|@src)][(@property and @content) or not(@property)]" mode="rdfa:resource-down">
  <xsl:param name="base" select="normalize-space((/html:html/html:head/html:base[@href])[1]/@href)"/>

  <xsl:if test="$DEBUG">
    <xsl:message>RESOURCE DOWN PASSTHRU <xsl:apply-templates select="." mode="element-dump"/></xsl:message>
  </xsl:if>

  <xsl:apply-templates select="html:*" mode="rdfa:resource-down">
    <xsl:with-param name="base" select="$base"/>
  </xsl:apply-templates>
</xsl:template>

<xsl:template match="html:*[not(@rel|@rev|@about|@typeof|@resource|@href|@src)][(@property and @content) or not(@property)]" mode="rdfa:resource-up">
  <xsl:param name="base" select="normalize-space((/html:html/html:head/html:base[@href])[1]/@href)"/>

  <xsl:if test="$DEBUG">
    <xsl:message>RESOURCE UP PASSTHRU</xsl:message>
  </xsl:if>

  <xsl:apply-templates select=".." mode="rdfa:resource-up">
    <xsl:with-param name="base" select="$base"/>
  </xsl:apply-templates>
</xsl:template>

<xsl:template match="html:*" mode="rdfa:resource-down">
  <xsl:param name="base" select="normalize-space((/html:html/html:head/html:base[@href])[1]/@href)"/>

  <xsl:if test="$DEBUG">
    <xsl:message>RESOURCE DOWN ACTUAL</xsl:message>
  </xsl:if>

  <xsl:text> </xsl:text>
  <xsl:variable name="_">
    <xsl:apply-templates select="." mode="rdfa:new-subject">
      <xsl:with-param name="base" select="$base"/>
    </xsl:apply-templates>
  </xsl:variable>
  <xsl:if test="$DEBUG">
    <xsl:message>look ma: <xsl:value-of select="$_"/></xsl:message>
  </xsl:if>
  <xsl:value-of select="$_"/>
  <xsl:text> </xsl:text>
</xsl:template>

<!-- XXX do we even need this? -->
<xsl:template match="html:*" mode="rdfa:resource-up">
  <xsl:param name="base" select="normalize-space((/html:html/html:head/html:base[@href])[1]/@href)"/>

  <xsl:if test="$DEBUG">
    <xsl:message>RESOURCE UP ACTUAL</xsl:message>
  </xsl:if>

</xsl:template>

<!--

<xsl:template match="html:*[not(@rel|@rev)]" mode="rdfa:resource-down">
</xsl:template>

<xsl:template match="html:*[@rel|@rev]" mode="rdfa:resource-down">
  <xsl:param name="base" select="normalize-space((/html:html/html:head/html:base[@href])[1]/@href)"/>
  <xsl:param name="start-with-object" select="false()"/>
</xsl:template>

-->

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
<xsl:message terminate="yes">THIS SHOULD NEVER GET RUN</xsl:message>
</xsl:template>

<xsl:template match="html:*" mode="rdfa:locate-rel-down">
  <xsl:if test="$DEBUG">
    <xsl:message>CALLED NOOP on <xsl:apply-templates select="." mode="element-dump"/></xsl:message>
  </xsl:if>
</xsl:template>

<xsl:template match="html:*[not(@rel|@rev|@resource|@href|@src)][not(@property) or (@property and @content)]" mode="rdfa:locate-rel-down">
  <xsl:param name="predicate" select="''"/>
  <xsl:param name="base" select="normalize-space((/html:html/html:head/html:base[@href])[1]/@href)"/>
  <xsl:param name="include-self" select="false()"/>
  <xsl:param name="probe" select="false()"/>

  <xsl:if test="not(string-length(normalize-space($predicate)))">
    <xsl:message terminate="yes">EMPTY PREDICATE</xsl:message>
  </xsl:if>

  <xsl:if test="$DEBUG">
    <xsl:message>CALLED PASSTHRU ON <xsl:apply-templates select="." mode="element-dump"/></xsl:message>
  </xsl:if>

  <xsl:if test="$include-self or not(@about|@typeof)">
    <xsl:apply-templates select="html:*[@rel]|html:*[not(@rel|@rev)][@property and @resource|@href|@src|@typeof]|html:*[not(@rel|@rev|@resource|@href|@src)][not(@property) or (@property and @content)]" mode="rdfa:locate-rel-down">
    <!--<xsl:apply-templates select="html:*" mode="rdfa:locate-rel-down">-->
      <xsl:with-param name="predicate" select="$predicate"/>
      <xsl:with-param name="base" select="$base"/>
      <xsl:with-param name="probe" select="$probe"/>
    </xsl:apply-templates>
  </xsl:if>
</xsl:template>

<xsl:template match="html:*[@rel or (not(@rel|@rev|@content|@datatype) and @property and @resource|@href|@src|@typeof)]" mode="rdfa:locate-rel-down">
  <xsl:param name="predicate" select="''"/>
  <xsl:param name="base" select="normalize-space((/html:html/html:head/html:base[@href])[1]/@href)"/>
  <xsl:param name="include-self" select="false()"/>
  <xsl:param name="probe" select="false()"/>

  <xsl:if test="not(string-length(normalize-space($predicate)))">
    <xsl:message terminate="yes">EMPTY PREDICATE ON ACTUAL THING</xsl:message>
  </xsl:if>

  <xsl:if test="$DEBUG">
    <xsl:message>CALLED ACTUAL THING</xsl:message>
  </xsl:if>

  <xsl:choose>
    <xsl:when test="not($include-self) and (@about or (@rel and @typeof))"/>
    <xsl:when test="@rel">
      <xsl:variable name="_">
        <xsl:text> </xsl:text>
        <xsl:call-template name="rdfa:resolve-curie-list">
          <xsl:with-param name="list" select="@rel"/>
          <xsl:with-param name="node" select="."/>
          <xsl:with-param name="base" select="$base"/>
        </xsl:call-template>
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
            </xsl:apply-templates>
          </xsl:otherwise>
        </xsl:choose>
        <xsl:text> </xsl:text>
      </xsl:if>
    </xsl:when>
    <xsl:when test="@property">
      <xsl:variable name="_">
        <xsl:text> </xsl:text>
        <xsl:call-template name="rdfa:resolve-curie-list">
          <xsl:with-param name="list" select="@property"/>
          <xsl:with-param name="node" select="."/>
          <xsl:with-param name="base" select="$base"/>
        </xsl:call-template>
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

<xsl:template match="*|@*" mode="rdfa:locate-property">
  <xsl:message terminate="yes">THIS SHOULD NEVER BE RUN</xsl:message>
</xsl:template>
<xsl:template match="html:*" mode="rdfa:locate-property"/>

<!--<xsl:template match=:html:*[not(@property) and (not(@rel|@rev) or @re-->

<xsl:template match="html:*[@property and (@rel|@rev or @content|@datatype)]" mode="rdfa:locate-property">
  <xsl:param name="predicate" select="''"/>
  <xsl:param name="base" select="normalize-space((/html:html/html:head/html:base[@href])[1]/@href)"/>
  <xsl:param name="probe" select="false()"/>

  <xsl:variable name="properties">
    <xsl:text> </xsl:text>
    <xsl:call-template name="rdfa:resolve-curie-list">
      <xsl:with-param name="list" select="@property"/>
      <xsl:with-param name="node" select="."/>
      <xsl:with-param name="base" select="$base"/>
    </xsl:call-template>
    <xsl:text> </xsl:text>
  </xsl:variable>

  <xsl:if test="contains($properties, concat(' ', $predicate, ' '))">
    <xsl:variable name="language">
      <xsl:variable name="_" select="ancestor-or-self::html:*[@xml:lang|@lang][1]"/>
      <xsl:choose>
        <xsl:when test="$_/@xml:lang"><xsl:value-of select="normalize-space(@xml:lang)"/></xsl:when>
        <xsl:when test="$_/@lang"><xsl:value-of select="normalize-space(@lang)"/></xsl:when>
        <xsl:otherwise/>
      </xsl:choose>
    </xsl:variable>

    <xsl:variable name="datatype">
      <xsl:call-template name="rdfa:resolve-curie">
        <xsl:with-param name="curie" select="@datatype"/>
        <xsl:with-param name="node" select="."/>
        <xsl:with-param name="base" select="$base"/>
      </xsl:call-template>
    </xsl:variable>

    <xsl:text>&#xf11e;</xsl:text>
    <xsl:choose>
      <xsl:when test="$datatype = concat($RDF-NS, 'XMLLiteral')">
        <xsl:value-of select="concat('#', generate-id(.))"/>
      </xsl:when>
      <xsl:when test="@content">
        <xsl:value-of select="@content"/>
      </xsl:when>
      <xsl:otherwise><xsl:value-of select="string(.)"/></xsl:otherwise>
    </xsl:choose>
    <xsl:text>&#xf11f;</xsl:text>
    <xsl:choose>
      <xsl:when test="string-length($datatype)">
        <xsl:value-of select="$datatype"/>
      </xsl:when>
      <xsl:when test="string-length($language)">
        <xsl:value-of select="concat('@', translate($language, 'ABCDEFGHIJKLMNOPQRSTUVWXYZ_', 'abcdefghijklmnopqrstuvwxyz-'))"/>
      </xsl:when>
    </xsl:choose>
    <xsl:text>&#xf11e;</xsl:text>
  </xsl:if>
  
</xsl:template>

<xsl:template match="html:*" mode="rdfa:locate-rev-down">
<xsl:if test="$DEBUG">
  <xsl:message>CALLED REV NOOP ON <xsl:value-of select="local-name()"/></xsl:message>
</xsl:if>
</xsl:template>

<xsl:template match="html:*[not(@rel|@rev|@about|@typeof|@resource|@href|@src)][not(@property) or (@property and @content)]" mode="rdfa:locate-rev-down">
  <xsl:param name="predicate" select="''"/>
  <xsl:param name="base" select="normalize-space((/html:html/html:head/html:base[@href])[1]/@href)"/>
  <xsl:param name="probe" select="false()"/>

  <xsl:if test="$DEBUG">
    <xsl:message>CALLED REV PASSTHRU ON <xsl:value-of select="local-name()"/></xsl:message>
  </xsl:if>

  <xsl:apply-templates select="html:*[@rev]|html:*[not(@rel|@rev|@about|@typeof|@resource|@href|@src)][not(@property) or (@property and @content)]" mode="rdfa:locate-rev-down">
    <xsl:with-param name="predicate" select="$predicate"/>
    <xsl:with-param name="base" select="$base"/>
    <xsl:with-param name="probe" select="$probe"/>
  </xsl:apply-templates>
</xsl:template>

<xsl:template match="html:*[@rev]" mode="rdfa:locate-rev-down">
  <xsl:param name="predicate" select="''"/>
  <xsl:param name="base" select="normalize-space((/html:html/html:head/html:base[@href])[1]/@href)"/>
  <xsl:param name="include-self" select="false()"/>
  <xsl:param name="probe" select="false()"/>

  <!-- this is very close to locate-rel-down except it does @rev and not
       @property -->

  <xsl:choose>
    <xsl:when test="not($include-self) and @about|@typeof"/>
    <xsl:otherwise>
      <xsl:variable name="_">
        <xsl:text> </xsl:text>
        <xsl:call-template name="rdfa:resolve-curie-list">
          <xsl:with-param name="list" select="@rev"/>
          <xsl:with-param name="node" select="."/>
          <xsl:with-param name="base" select="$base"/>
        </xsl:call-template>
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
            </xsl:apply-templates>
          </xsl:otherwise>
        </xsl:choose>
        <xsl:text> </xsl:text>
      </xsl:if>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<xsl:template match="*|@*" mode="rdfa:locate-rev-up">
  <xsl:message terminate="yes">THIS SHOULD NEVER GET RUN</xsl:message>
</xsl:template>

<xsl:template match="html:*" mode="rdfa:locate-rev-up">
<xsl:if test="$DEBUG">
  <xsl:message>CALLED REV NOOP ON <xsl:value-of select="local-name()"/></xsl:message>
</xsl:if>
</xsl:template>

<xsl:template match="html:*[not(@rel|@rev|@about|@typeof|@resource|@href|@src)][not(@property) or (@property and @content)]" mode="rdfa:locate-rev-up">
  <xsl:param name="predicate" select="''"/>
  <xsl:param name="base" select="normalize-space((/html:html/html:head/html:base[@href])[1]/@href)"/>
  <xsl:param name="probe" select="false()"/>

  <xsl:if test="$DEBUG">
    <xsl:message>CALLED REV PASSTHRU ON <xsl:value-of select="local-name()"/></xsl:message>
  </xsl:if>

  <xsl:apply-templates select="parent::html:*[@rev]|parent::html:*[not(@rel|@rev|@about|@typeof|@resource|@href|@src)][not(@property) or (@property and @content)]" mode="rdfa:locate-rev-up">
    <xsl:with-param name="predicate" select="$predicate"/>
    <xsl:with-param name="base" select="$base"/>
    <xsl:with-param name="probe" select="$probe"/>
  </xsl:apply-templates>
</xsl:template>

<xsl:template match="html:*[@rev]" mode="rdfa:locate-rev-up">
  <xsl:param name="predicate" select="''"/>
  <xsl:param name="base" select="normalize-space((/html:html/html:head/html:base[@href])[1]/@href)"/>
  <xsl:param name="include-self" select="false()"/>
  <xsl:param name="probe" select="false()"/>

  <!-- the rev has to exist *and* match for further processing or
       otherwise there can't be any other resource/macro node -->

  <xsl:choose>
    <xsl:when test="not($include-self) and (@resource|@href|@src or (@typeof and not(@about)))"/>
    <xsl:otherwise>
      <xsl:variable name="_">
        <xsl:text> </xsl:text>
        <xsl:call-template name="rdfa:resolve-curie-list">
          <xsl:with-param name="list" select="@rev"/>
          <xsl:with-param name="node" select="."/>
          <xsl:with-param name="base" select="$base"/>
        </xsl:call-template>
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

<xsl:template match="*|@*" mode="rdfa:locate-rel-up">
  <xsl:message terminate="yes">THIS SHOULD NEVER GET RUN</xsl:message>
</xsl:template>

<xsl:template match="html:*" mode="rdfa:locate-rel-up"/>

<!-- this xpath is just copied so it might not be right or it might be -->
<xsl:template match="html:*[not(@rel|@rev|@about|@typeof|@resource|@href|@src)][not(@property) or (@property and @content)]" mode="rdfa:locate-rev-up">
  <xsl:param name="predicate" select="''"/>
  <xsl:param name="base" select="normalize-space((/html:html/html:head/html:base[@href])[1]/@href)"/>
  <xsl:param name="probe" select="false()"/>

  <xsl:if test="$DEBUG">
    <xsl:message>CALLED REL UP PASSTHRU ON <xsl:value-of select="local-name()"/></xsl:message>
  </xsl:if>

  <xsl:apply-templates select="parent::html:*[@rel or (not(@rel|@rev|@content|@datatype) and @property and @resource|@href|@src|@typeof)]|parent::html:*[not(@rel|@rev|@about|@typeof|@resource|@href|@src)][not(@property) or (@property and @content)]" mode="rdfa:locate-rev-up">
    <xsl:with-param name="predicate" select="$predicate"/>
    <xsl:with-param name="base" select="$base"/>
    <xsl:with-param name="probe" select="$probe"/>
  </xsl:apply-templates>
</xsl:template>

<xsl:template match="html:*[@rel or (not(@rel|@rev|@content|@datatype) and @property and @resource|@href|@src|@typeof)]" mode="rdfa:locate-rel-up">
  <xsl:param name="predicate" select="''"/>
  <xsl:param name="base" select="normalize-space((/html:html/html:head/html:base[@href])[1]/@href)"/>
  <xsl:param name="include-self" select="false()"/>
  <xsl:param name="probe" select="false()"/>

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
        <xsl:call-template name="rdfa:resolve-curie-list">
          <xsl:with-param name="list" select="$p"/>
          <xsl:with-param name="node" select="."/>
          <xsl:with-param name="base" select="$base"/>
        </xsl:call-template>
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


<xsl:template match="html:*|html:*/@*" mode="rdfa:subject-node">
  <xsl:param name="subject" select="''"/>
  <xsl:param name="predicate" select="''"/>
  <xsl:param name="base" select="normalize-space((/html:html/html:head/html:base[@href])[1]/@href)"/>
  <xsl:param name="probe" select="false()"/>

  <!-- i suppose the first thing to do is determine if we're looking a
       subject, an object, or just a meaningless resource -->

  <!-- the parenthesis puts this expression in document order; parent
       node (..) always precedes the current node in document order. -->
  <xsl:variable name="element" select="(self::*|..)[last()]"/>

  <xsl:if test="$DEBUG">
  <xsl:message>
    <xsl:text>SPO: </xsl:text>
    <xsl:value-of select="$subject"/><xsl:text> </xsl:text>
    <xsl:apply-templates select="$element" mode="element-dump"/>
  </xsl:message>
  </xsl:if>

  <xsl:if test="$predicate = concat($RDF-NS, 'type') and $element/@typeof">
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
      <xsl:if test="$DEBUG">
        <xsl:message>CALLED WITH SUBJECT <xsl:apply-templates select="$element" mode="element-dump"/></xsl:message>
      </xsl:if>
      <!-- omg forgetting $element here literally cost me 5 hours -->
      <xsl:apply-templates select="$element/parent::html:*[@rev]|$element/parent::html:*[not(@rel|@rev|@about|@typeof|@resource|@href|@src)][not(@property) or (@property and @content)]" mode="rdfa:locate-rev-up">
        <xsl:with-param name="predicate" select="$predicate"/>
        <xsl:with-param name="base" select="$base"/>
        <xsl:with-param name="include-self" select="false()"/>
        <xsl:with-param name="probe" select="$probe"/>
      </xsl:apply-templates>
      <!-- if i remove this -->
      <!--<xsl:apply-templates select="self::html:*[@rel]|self::html:*[not(@rel|@rev)][(@property and @content) or not(@property)]" mode="rdfa:locate-rel-down">-->
      <xsl:apply-templates select="$element" mode="rdfa:locate-rel-down">
        <xsl:with-param name="predicate" select="$predicate"/>
        <xsl:with-param name="base" select="$base"/>
        <xsl:with-param name="include-self" select="true()"/>
        <xsl:with-param name="probe" select="$probe"/>
      </xsl:apply-templates>
    </xsl:when>
    <xsl:otherwise>
      <!-- descendant rel|property; ancestor-or-self rev -->
      <xsl:if test="$DEBUG">
        <xsl:message>CALLED WITH OBJECT</xsl:message>
      </xsl:if>
      <xsl:apply-templates select="$element/self::html:*[@rev]|$element/self::html:*[not(@rel|@rev|@about|@typeof|@resource|@href|@src)][not(@property) or (@property and @content)]" mode="rdfa:locate-rev-up">
        <!--<xsl:apply-templates select="." mode="rdfa:locate-rev-up">-->
        <xsl:with-param name="predicate" select="$predicate"/>
        <xsl:with-param name="base" select="$base"/>
        <xsl:with-param name="include-self" select="true()"/>
        <xsl:with-param name="probe" select="$probe"/>
      </xsl:apply-templates>
      <xsl:apply-templates select="$element/html:*[@rel]|$element/html:*[not(@rel|@rev)][(@property and @content) or not(@property)]|$element/html:*[not(@rel|@rev|@about|@typeof|@resource|@href|@src)][not(@property) or (@property and @content)]" mode="rdfa:locate-rel-down">
        <xsl:with-param name="predicate" select="$predicate"/>
        <xsl:with-param name="base" select="$base"/>
        <xsl:with-param name="include-self" select="false()"/>
        <xsl:with-param name="probe" select="$probe"/>
      </xsl:apply-templates>
    </xsl:otherwise>
  </xsl:choose>

</xsl:template>



<xsl:template match="html:*|html:*/@*" mode="rdfa:object-node">
  <xsl:param name="predicate" select="''"/>
  <xsl:param name="object" select="''"/>
  <xsl:param name="base" select="normalize-space((/html:html/html:head/html:base[@href])[1]/@href)"/>
  <xsl:variable name="probe" select="false()"/>

  <xsl:variable name="element" select="(self::*|..)[last()]"/>

  <xsl:if test="$DEBUG">
  <xsl:message>
    <xsl:text>OPS: </xsl:text>
    <xsl:value-of select="$object"/><xsl:text> </xsl:text>
    <xsl:apply-templates select="$element" mode="element-dump"/>
  </xsl:message>
  </xsl:if>

  <xsl:variable name="is-subject">
    <xsl:apply-templates select="." mode="rdfa:is-subject"/>
  </xsl:variable>

  <xsl:choose>
    <xsl:when test="string-length($is-subject)">
      <xsl:apply-templates select="$element/parent::html:*[@rel]|$element/parent::html:*[not(@rel|@rev|@about|@typeof|@resource|@href|@src)][not(@property) or (@property and @content)]" mode="rdfa:locate-rel-up">
        <xsl:with-param name="predicate" select="$predicate"/>
        <xsl:with-param name="base" select="$base"/>
        <xsl:with-param name="include-self" select="false()"/>
        <xsl:with-param name="probe" select="$probe"/>
      </xsl:apply-templates>
      <!--<xsl:apply-templates select="self::html:*[@rev]|self::html:*[not(@rel|@rev)][(@property and @content) or not(@property)]" mode="rdfa:locate-rev-down">-->
      <xsl:apply-templates select="$element" mode="rdfa:locate-rev-down">
        <xsl:with-param name="predicate" select="$predicate"/>
        <xsl:with-param name="base" select="$base"/>
        <xsl:with-param name="include-self" select="true()"/>
        <xsl:with-param name="probe" select="$probe"/>
      </xsl:apply-templates>
    </xsl:when>
    <xsl:otherwise>
      <xsl:apply-templates select="$element/self::html:*[@rel]|$element/self::html:*[not(@rel|@rev|@about|@typeof|@resource|@href|@src)][not(@property) or (@property and @content)]" mode="rdfa:locate-rel-up">
        <!--<xsl:apply-templates select="." mode="rdfa:locate-rel-up">-->
        <xsl:with-param name="predicate" select="$predicate"/>
        <xsl:with-param name="base" select="$base"/>
        <xsl:with-param name="include-self" select="true()"/>
        <xsl:with-param name="probe" select="$probe"/>
      </xsl:apply-templates>
      <xsl:apply-templates select="$element/html:*[@rev]|$element/html:*[not(@rel|@rev)][(@property and @content) or not(@property)]" mode="rdfa:locate-rev-down">
        <xsl:with-param name="predicate" select="$predicate"/>
        <xsl:with-param name="base" select="$base"/>
        <xsl:with-param name="include-self" select="false()"/>
        <xsl:with-param name="probe" select="$probe"/>
      </xsl:apply-templates>
    </xsl:otherwise>
  </xsl:choose>

</xsl:template>

<xsl:template name="rdfa:object-resource-internal">
  <xsl:param name="subject" select="''"/>
  <xsl:param name="predicate" select="''"/>
  <xsl:param name="current" select="."/>
  <xsl:param name="base" select="normalize-space((/html:html/html:head/html:base[@href])[1]/@href)"/>
  <xsl:param name="probe" select="false()"/>

  <xsl:variable name="resource" select="$subject"/>

  <xsl:choose>
    <xsl:when test="starts-with($resource, '_:')">
      <xsl:apply-templates select="key('rdfa:uri-node', $resource)|key('rdfa:reverse-node-id', substring-after($resource, '_:'))" mode="rdfa:subject-node">
        <xsl:with-param name="subject" select="$resource"/>
        <xsl:with-param name="predicate" select="$predicate"/>
        <xsl:with-param name="base" select="$base"/>
        <xsl:with-param name="probe" select="$probe"/>
      </xsl:apply-templates>
    </xsl:when>
    <xsl:otherwise>

      <!-- do special cases for root -->
      <xsl:variable name="root-resource">
        <xsl:apply-templates select="ancestor-or-self::html:html[1]" mode="rdfa:new-subject">
          <xsl:with-param name="base" select="$base"/>
        </xsl:apply-templates>
      </xsl:variable>
      <xsl:if test="$root-resource = $resource">
        <xsl:apply-templates select="(ancestor-or-self::html:html[1]|ancestor-or-self::html:html[1]/html:head[1]|ancestor-or-self::html:html[1]/html:body[1])[@rel|@rev|@property|@typeof][not(@about|@resource|@href|@src)]" mode="rdfa:subject-node">
          <xsl:with-param name="subject" select="$resource"/>
          <xsl:with-param name="predicate" select="$predicate"/>
          <xsl:with-param name="base" select="$base"/>
          <xsl:with-param name="probe" select="$probe"/>
        </xsl:apply-templates>
      </xsl:if>

      <!-- do absolute uri -->
      <xsl:apply-templates select="key('rdfa:uri-node', $resource)" mode="rdfa:subject-node">
        <xsl:with-param name="subject" select="$resource"/>
        <xsl:with-param name="predicate" select="$predicate"/>
        <xsl:with-param name="base" select="$base"/>
        <xsl:with-param name="probe" select="$probe"/>
      </xsl:apply-templates>

      <!-- do relative uri -->
      <xsl:variable name="resource-rel-strict">
        <xsl:call-template name="uri:make-relative-uri">
          <xsl:with-param name="uri" select="$resource"/>
          <xsl:with-param name="base" select="$base"/>
          <xsl:with-param name="strict" select="true()"/>
        </xsl:call-template>
      </xsl:variable>
      <xsl:if test="$resource-rel-strict != $resource">
        <xsl:variable name="resource-rel-lax">
          <xsl:call-template name="uri:make-relative-uri">
            <xsl:with-param name="uri" select="$resource"/>
            <xsl:with-param name="base" select="$base"/>
            <xsl:with-param name="strict" select="false()"/>
          </xsl:call-template>
        </xsl:variable>
        <xsl:variable name="resource-rel-full">
          <xsl:call-template name="uri:local-part">
            <xsl:with-param name="uri" select="$resource"/>
            <xsl:with-param name="base" select="$base"/>
          </xsl:call-template>
        </xsl:variable>

        <xsl:apply-templates select="key('rdfa:uri-node', $resource-rel-strict)|key('rdfa:uri-node', $resource-rel-lax)|key('rdfa:uri-node', $resource-rel-full)" mode="rdfa:subject-node">
          <xsl:with-param name="subject" select="$resource"/>
          <xsl:with-param name="predicate" select="$predicate"/>
          <xsl:with-param name="base" select="$base"/>
          <xsl:with-param name="probe" select="$probe"/>
        </xsl:apply-templates>
      </xsl:if>

      <!-- do curie -->
      <xsl:variable name="resource-curie">
        <xsl:call-template name="rdfa:make-curie">
          <xsl:with-param name="uri" select="$resource"/>
        </xsl:call-template>
      </xsl:variable>
      <xsl:if test="string-length($resource-curie)">
        <xsl:apply-templates select="key('rdfa:curie-node', $resource-curie)|key('rdfa:curie-node', concat('[', $resource-curie, ']'))" mode="rdfa:subject-node">
          <xsl:with-param name="subject" select="$resource"/>
          <xsl:with-param name="predicate" select="$predicate"/>
          <xsl:with-param name="base" select="$base"/>
          <xsl:with-param name="probe" select="$probe"/>
        </xsl:apply-templates>
      </xsl:if>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<xsl:template name="rdfa:object-resources">
  <xsl:param name="subject" select="''"/>
  <xsl:param name="predicate" select="''"/>
  <xsl:param name="current" select="."/>
  <xsl:param name="local-base" select="normalize-space((/html:html/html:head/html:base[@href])[1]/@href)"/>
  <xsl:param name="base" select="$local-base"/>

  <xsl:variable name="resource-list">
    <xsl:call-template name="rdfa:resolve-curie-list">
      <xsl:with-param name="list">
        <xsl:call-template name="str:unique-tokens">
          <xsl:with-param name="string" select="$subject"/>
        </xsl:call-template>
      </xsl:with-param>
      <xsl:with-param name="node" select="$current"/>
      <xsl:with-param name="base" select="$base"/>
    </xsl:call-template>
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
    </xsl:call-template>
  </xsl:variable>

  <xsl:variable name="raw-resource-list">
    <xsl:text> </xsl:text>
    <xsl:call-template name="rdfa:object-resource-internal">
      <xsl:with-param name="subject" select="$first-resource"/>
      <xsl:with-param name="predicate" select="$predicate-absolute"/>
      <xsl:with-param name="base" select="$base"/>
    </xsl:call-template>
<!--
  <xsl:choose>
    <xsl:when test="starts-with($first-resource, '_:')">
      <xsl:apply-templates select="key('rdfa:uri-node', $first-resource)|key('rdfa:reverse-node-id', substring-after($first-resource, '_:'))" mode="rdfa:subject-node">
        <xsl:with-param name="subject" select="$first-resource"/>
        <xsl:with-param name="predicate" select="$predicate-absolute"/>
        <xsl:with-param name="base" select="$base"/>
      </xsl:apply-templates>
    </xsl:when>
    <xsl:otherwise>
-->
      <!-- do special cases for root --><!--
      <xsl:variable name="root-resource">
        <xsl:apply-templates select="ancestor-or-self::html:html[1]" mode="rdfa:new-subject">
          <xsl:with-param name="base" select="$base"/>
        </xsl:apply-templates>
      </xsl:variable>
      <xsl:if test="$root-resource = $first-resource">
        <xsl:apply-templates select="(ancestor-or-self::html:html[1]|ancestor-or-self::html:html[1]/html:head[1]|ancestor-or-self::html:html[1]/html:body[1])[@rel|@rev|@property|@typeof][not(@about|@resource|@href|@src)]" mode="rdfa:subject-node">
          <xsl:with-param name="subject" select="$first-resource"/>
          <xsl:with-param name="predicate" select="$predicate-absolute"/>
          <xsl:with-param name="base" select="$base"/>
        </xsl:apply-templates>
      </xsl:if>
-->
      <!-- do absolute uri --><!--
      <xsl:apply-templates select="key('rdfa:uri-node', $first-resource)" mode="rdfa:subject-node">
        <xsl:with-param name="subject" select="$first-resource"/>
        <xsl:with-param name="predicate" select="$predicate-absolute"/>
        <xsl:with-param name="base" select="$base"/>
      </xsl:apply-templates>
-->
      <!-- do relative uri --><!--
      <xsl:variable name="resource-rel-strict">
        <xsl:call-template name="uri:make-relative-uri">
          <xsl:with-param name="uri" select="$first-resource"/>
          <xsl:with-param name="base" select="$base"/>
          <xsl:with-param name="strict" select="true()"/>
        </xsl:call-template>
      </xsl:variable>
      <xsl:if test="$resource-rel-strict != $first-resource">
        <xsl:variable name="resource-rel-lax">
          <xsl:call-template name="uri:make-relative-uri">
            <xsl:with-param name="uri" select="$first-resource"/>
            <xsl:with-param name="base" select="$base"/>
            <xsl:with-param name="strict" select="false()"/>
          </xsl:call-template>
        </xsl:variable>
        <xsl:variable name="resource-rel-full">
          <xsl:call-template name="uri:local-part">
            <xsl:with-param name="uri" select="$first-resource"/>
            <xsl:with-param name="base" select="$base"/>
          </xsl:call-template>
        </xsl:variable>
-->
        <!--<xsl:message>'<xsl:value-of select="$subject-rel-strict"/>' '<xsl:value-of select="$subject-rel-lax"/>' '<xsl:value-of select="$subject-rel-full"/>'</xsl:message>-->
<!--
        <xsl:apply-templates select="key('rdfa:uri-node', $resource-rel-strict)|key('rdfa:uri-node', $resource-rel-lax)|key('rdfa:uri-node', $resource-rel-full)" mode="rdfa:subject-node">
          <xsl:with-param name="subject" select="$first-resource"/>
          <xsl:with-param name="predicate" select="$predicate-absolute"/>
          <xsl:with-param name="base" select="$base"/>
        </xsl:apply-templates>
      </xsl:if>
-->
      <!-- do curie --><!--
      <xsl:variable name="resource-curie">
        <xsl:call-template name="rdfa:make-curie">
          <xsl:with-param name="uri" select="$first-resource"/>
        </xsl:call-template>
      </xsl:variable>
      <xsl:if test="string-length($resource-curie)">
        <xsl:apply-templates select="key('rdfa:curie-node', $resource-curie)|key('rdfa:curie-node', concat('[', $resource-curie, ']'))" mode="rdfa:subject-node">
          <xsl:with-param name="subject" select="$first-resource"/>
          <xsl:with-param name="predicate" select="$predicate-absolute"/>
          <xsl:with-param name="base" select="$base"/>
        </xsl:apply-templates>
      </xsl:if>
    </xsl:otherwise>
  </xsl:choose>
-->
  <xsl:if test="string-length(substring-after(normalize-space($resource-list), ' '))">
    <xsl:call-template name="rdfa:object-resources">
      <xsl:with-param name="subject" select="substring-after(normalize-space($resource-list), ' ')"/>
      <xsl:with-param name="predicate" select="$predicate-absolute"/>
      <xsl:with-param name="base" select="$base"/>
    </xsl:call-template>
  </xsl:if>

  </xsl:variable>

  <!-- TODO unique tokens -->
  <xsl:call-template name="str:unique-tokens">
    <xsl:with-param name="string" select="$raw-resource-list"/>
  </xsl:call-template>
  <!--<xsl:value-of select="$raw-resource-list"/>-->

</xsl:template>

<xsl:template name="rdfa:subject-resources">
  <xsl:param name="predicate" select="''"/>
  <xsl:param name="object" select="''"/>
  <xsl:param name="current" select="."/>
  <xsl:param name="local-base" select="normalize-space((/html:html/html:head/html:base[@href])[1]/@href)"/>
  <xsl:param name="base" select="$local-base"/>

  <xsl:variable name="resource-list">
    <xsl:call-template name="rdfa:resolve-curie-list">
      <xsl:with-param name="list">
        <xsl:call-template name="str:unique-tokens">
          <xsl:with-param name="string" select="$object"/>
        </xsl:call-template>
      </xsl:with-param>
      <xsl:with-param name="node" select="$current"/>
      <xsl:with-param name="base" select="$base"/>
    </xsl:call-template>
  </xsl:variable>

  <!--<xsl:message>WTF <xsl:value-of select="$object"/></xsl:message>-->

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
    </xsl:call-template>
  </xsl:variable>

  <!-- DON'T FORGET SUBJECT(S) FOR TYPEOF -->

  <xsl:variable name="raw-resource-list">
  <xsl:choose>
    <xsl:when test="starts-with($first-resource, '_:')">
      <xsl:apply-templates select="key('rdfa:uri-node', $first-resource)|key('rdfa:reverse-node-id', substring-after($first-resource, '_:'))" mode="rdfa:object-node">
        <xsl:with-param name="predicate" select="$predicate-absolute"/>
        <xsl:with-param name="object" select="$first-resource"/>
        <xsl:with-param name="base" select="$base"/>
      </xsl:apply-templates>
    </xsl:when>
    <xsl:otherwise>
      <!-- do special cases for root -->
      <xsl:variable name="root-resource">
        <xsl:apply-templates select="ancestor-or-self::html:html[1]" mode="rdfa:new-subject">
          <xsl:with-param name="base" select="$base"/>
        </xsl:apply-templates>
      </xsl:variable>

      <!--<xsl:message>ROOT RESOURCE <xsl:value-of select="$root-resource"/> FIRST RESOURCE <xsl:value-of select="$first-resource"/></xsl:message>-->

      <xsl:if test="$root-resource = $first-resource">
        <xsl:apply-templates select="($current/ancestor-or-self::html:html[1]|$current/ancestor-or-self::html:html[1]/html:head[1]|$current/ancestor-or-self::html:html[1]/html:body[1])[@rel|@rev|@property|@typeof][not(@about|@resource|@href|@src)]" mode="rdfa:object-node">
          <xsl:with-param name="predicate" select="$predicate-absolute"/>
          <xsl:with-param name="object" select="$first-resource"/>
          <xsl:with-param name="base" select="$base"/>
        </xsl:apply-templates>
      </xsl:if>

      <!-- do absolute uri -->
      <xsl:apply-templates select="key('rdfa:uri-node', $first-resource)" mode="rdfa:object-node">
        <xsl:with-param name="predicate" select="$predicate-absolute"/>
        <xsl:with-param name="object" select="$first-resource"/>
        <xsl:with-param name="base" select="$base"/>
      </xsl:apply-templates>

      <!-- do relative uri -->
      <xsl:variable name="resource-rel-strict">
        <xsl:call-template name="uri:make-relative-uri">
          <xsl:with-param name="uri" select="$first-resource"/>
          <xsl:with-param name="base" select="$base"/>
          <xsl:with-param name="strict" select="true()"/>
        </xsl:call-template>
      </xsl:variable>
      <xsl:if test="$resource-rel-strict != $first-resource">
        <xsl:variable name="resource-rel-lax">
          <xsl:call-template name="uri:make-relative-uri">
            <xsl:with-param name="uri" select="$first-resource"/>
            <xsl:with-param name="base" select="$base"/>
            <xsl:with-param name="strict" select="false()"/>
          </xsl:call-template>
        </xsl:variable>
        <xsl:variable name="resource-rel-full">
          <xsl:call-template name="uri:local-part">
            <xsl:with-param name="uri" select="$first-resource"/>
            <xsl:with-param name="base" select="$base"/>
          </xsl:call-template>
        </xsl:variable>

        <xsl:apply-templates select="key('rdfa:uri-node', $resource-rel-strict)|
                                     key('rdfa:uri-node', $resource-rel-lax)|
                                     key('rdfa:uri-node', $resource-rel-full)"
                             mode="rdfa:object-node">
          <xsl:with-param name="predicate" select="$predicate-absolute"/>
          <xsl:with-param name="object" select="$first-resource"/>
          <xsl:with-param name="base" select="$base"/>
        </xsl:apply-templates>
      </xsl:if>

      <!-- do curie -->
      <xsl:variable name="resource-curie">
        <xsl:call-template name="rdfa:make-curie">
          <xsl:with-param name="uri" select="$first-resource"/>
        </xsl:call-template>
      </xsl:variable>
      <xsl:if test="string-length($resource-curie)">
        <xsl:if test="$DEBUG">
          <xsl:message>CURIE <xsl:value-of select="$resource-curie"/></xsl:message>
        </xsl:if>
        <xsl:apply-templates select="key('rdfa:curie-node', $resource-curie)|key('rdfa:curie-node', concat('[', $resource-curie, ']'))" mode="rdfa:object-node">
          <xsl:with-param name="predicate" select="$predicate-absolute"/>
          <xsl:with-param name="object" select="$first-resource"/>
          <xsl:with-param name="base" select="$base"/>
        </xsl:apply-templates>
      </xsl:if>
    </xsl:otherwise>
  </xsl:choose>

  <xsl:if test="string-length(substring-after(normalize-space($resource-list), ' '))">
    <xsl:call-template name="rdfa:subject-resources">
      <xsl:with-param name="predicate" select="$predicate-absolute"/>
      <xsl:with-param name="object" select="substring-after(normalize-space($resource-list), ' ')"/>
      <xsl:with-param name="base" select="$base"/>
    </xsl:call-template>
  </xsl:if>
  </xsl:variable>

  <!-- eventually this will be unique tokens -->
  <xsl:call-template name="str:unique-tokens">
    <xsl:with-param name="string" select="$raw-resource-list"/>
  </xsl:call-template>
  <!--<xsl:value-of select="$raw-resource-list"/>-->

</xsl:template>

<xsl:template name="rdfa:subjects-for-literal">
  <xsl:param name="base" select="normalize-space((/html:html/html:head/html:base[@href])[1]/@href)"/>
  <xsl:param name="current"   select="."/>
  <xsl:param name="predicate" select="''"/>
  <xsl:param name="language"  select="''"/>
  <xsl:param name="datatype"  select="''"/>
  <xsl:param name="value"     select="''"/>

  <xsl:variable name="predicate-absolute">
    <xsl:call-template name="rdfa:resolve-curie">
      <xsl:with-param name="curie" select="$predicate"/>
      <xsl:with-param name="node" select="$current"/>
      <xsl:with-param name="base" select="$base"/>
    </xsl:call-template>
  </xsl:variable>

  <xsl:for-each select="key('rdfa:literal-content-node', $value)|
                        key('rdfa:literal-text-node', $value)">
    <xsl:variable name="_">
      <xsl:text> </xsl:text>
      <xsl:call-template name="rdfa:resolve-curie-list">
        <xsl:with-param name="list" select="@property"/>
        <xsl:with-param name="node" select="."/>
        <xsl:with-param name="base" select="$base"/>
      </xsl:call-template>
      <xsl:text> </xsl:text>
    </xsl:variable>

    <xsl:if test="contains($_, $predicate-absolute)">
    <xsl:message>sup dawg</xsl:message>
      <xsl:text> </xsl:text>
      <xsl:apply-templates select="." mode="rdfa:new-subject">
        <xsl:with-param name="base" select="$base"/>
      </xsl:apply-templates>
      <xsl:text> </xsl:text>
    </xsl:if>
  </xsl:for-each>

</xsl:template>

<xsl:template name="rdfa:object-literal-internal">
  <xsl:param name="subject"   select="''"/>
  <xsl:param name="predicate" select="''"/>
  <xsl:param name="language"  select="''"/>
  <xsl:param name="datatype"  select="''"/>
  <xsl:param name="current"   select="."/>


</xsl:template>

<xsl:template name="rdfa:object-literal-quick">
  <xsl:param name="subject"   select="''"/>
  <xsl:param name="predicate" select="''"/>
  <xsl:param name="language"  select="''"/>
  <xsl:param name="datatype"  select="''"/>
  <xsl:param name="current"   select="."/>
</xsl:template>

<xsl:template name="rdfa:object-literals">
  <xsl:param name="subject"   select="''"/>
  <xsl:param name="predicate" select="''"/>
  <xsl:param name="language"  select="''"/>
  <xsl:param name="datatype"  select="''"/>
  <xsl:param name="current"   select="."/>


</xsl:template>

<xsl:template name="rdfa:coded-objects">
</xsl:template>

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
    </xsl:call-template>
  </xsl:variable>

  <xsl:choose>
    <xsl:when test="string-length(normalize-space($subject))">

      <xsl:variable name="resource-list">
        <xsl:call-template name="rdfa:resolve-curie-list">
          <xsl:with-param name="list">
            <xsl:call-template name="str:unique-tokens">
              <xsl:with-param name="string" select="$subject"/>
            </xsl:call-template>
          </xsl:with-param>
          <xsl:with-param name="node" select="$current"/>
          <xsl:with-param name="base" select="$base"/>
        </xsl:call-template>
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
        <xsl:call-template name="rdfa:object-resource-internal">
          <xsl:with-param name="subject" select="$first-resource"/>
          <xsl:with-param name="predicate" select="$predicate-absolute"/>
          <xsl:with-param name="base" select="$base"/>
          <xsl:with-param name="probe" select="true()"/>
        </xsl:call-template>
      </xsl:variable>
      <xsl:if test="$test">
        <xsl:value-of select="concat(' ', $subject, ' ')"/>
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
        <xsl:call-template name="rdfa:resolve-curie-list">
          <xsl:with-param name="list">
            <xsl:call-template name="str:unique-tokens">
              <xsl:with-param name="string" select="$object"/>
            </xsl:call-template>
          </xsl:with-param>
          <xsl:with-param name="node" select="$current"/>
          <xsl:with-param name="base" select="$base"/>
        </xsl:call-template>
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

</xsl:template>

</xsl:stylesheet>