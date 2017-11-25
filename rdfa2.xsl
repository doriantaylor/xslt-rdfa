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

<!-- ### HERE IS A CRAPLOAD OF KEYS ### -->

<xsl:key name="rdfa:reverse-node-id" match="html:html|html:head|html:body|html:*[@about|@typeof|@resource|@href|@src|@rel|@rev|@property|@inlist]|html:*[@about|@typeof|@resource|@href|@src|@rel|@rev|@property|@inlist]/@*" use="generate-id(.)"/>

<xsl:key name="rdfa:has-typeof" match="html:*[@typeof]" use="''"/>

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

<xsl:variable name="uri:DEBUG"       select="false()"/>
<xsl:variable name="rdfa:DEBUG"      select="false()"/>
<xsl:variable name="rdfa:RECORD-SEP" select="'&#xf11e;'"/>
<xsl:variable name="rdfa:UNIT-SEP"   select="'&#xf11f;'"/>
<xsl:variable name="rdfa:RDF-NS"     select="'http://www.w3.org/1999/02/22-rdf-syntax-ns#'"/>
<xsl:variable name="rdfa:XSD-NS"     select="'http://www.w3.org/2001/XMLSchema#'"/>

<!--
    ### THIS IS ALL STUFF THAT COMES STRAIGHT FROM XSLTSL ###
-->

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

<xsl:template name="uri:get-uri-scheme">
  <xsl:param name="uri"/>
  <xsl:if test="contains($uri, ':')">
    <xsl:value-of select="substring-before($uri, ':')"/>
  </xsl:if>
</xsl:template>

<xsl:template name="uri:get-uri-authority">
  <xsl:param name="uri"/>
  <xsl:variable name="a">
    <xsl:choose>
      <xsl:when test="contains($uri, ':')">
        <xsl:if test="substring(substring-after($uri, ':'), 1, 2) = '//'">
          <xsl:value-of select="substring(substring-after($uri, ':'), 3)"/>
        </xsl:if>
      </xsl:when>
      <xsl:otherwise>
        <xsl:if test="substring($uri, 1, 2) = '//'">
          <xsl:value-of select="substring($uri, 3)"/>
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

<xsl:template name="uri:get-uri-path">
  <xsl:param name="uri"/>
  <xsl:variable name="p">
    <xsl:choose>
      <xsl:when test="contains($uri, '//')">
        <xsl:if test="contains(substring-after($uri, '//'), '/')">
          <xsl:value-of select="concat('/', substring-after(substring-after($uri, '//'), '/'))"/>
        </xsl:if>
      </xsl:when>
      <xsl:otherwise>
        <xsl:choose>
          <xsl:when test="contains($uri, ':')">
            <xsl:value-of select="substring-after($uri, ':')"/>
          </xsl:when>
          <xsl:otherwise>
            <xsl:value-of select="$uri"/>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:variable>
  <xsl:choose>
    <xsl:when test="contains($p, '?')">
      <xsl:value-of select="substring-before($p, '?')" />
    </xsl:when>
    <xsl:when test="contains($p, '#')">
      <xsl:value-of select="substring-before($p, '#')" />
    </xsl:when>
    <xsl:otherwise>
      <xsl:value-of select="$p" />
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

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

<xsl:template name="uri:get-uri-fragment">
  <xsl:param name="uri"/>
  <xsl:value-of select="substring-after($uri, '#')"/>
</xsl:template>

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
  <xsl:param name="uri:DEBUG" select="false()"/>

  <xsl:if test="$uri:DEBUG">
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
  <xsl:param name="uri:DEBUG" select="false()"/>

  <xsl:variable name="abs-base" select="normalize-space($base)"/>
  <xsl:variable name="abs-uri">
    <xsl:call-template name="uri:resolve-uri">
      <xsl:with-param name="reference" select="normalize-space($uri)"/>
      <xsl:with-param name="base" select="$abs-base"/>
    </xsl:call-template>
  </xsl:variable>

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

  <xsl:variable name="_norm" select="normalize-space($string)"/>

  <xsl:choose>
    <xsl:when test="$_norm  = ''"><xsl:value-of select="$cache"/></xsl:when>
    <xsl:when test="contains($_norm, ' ')">
      <xsl:variable name="first" select="substring-before($_norm, ' ')"/>
      <xsl:variable name="rest"  select="substring-after($_norm, ' ')"/>

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
            <xsl:with-param name="string" select="$rest"/>
            <xsl:with-param name="cache"  select="$cache-out"/>
          </xsl:call-template>
        </xsl:when>
        <xsl:when test="contains(concat(' ', $cache-out, ' '), concat(' ' , $rest, ' '))">
          <xsl:value-of select="$cache-out"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="concat($cache-out, $rest, ' ')"/>
        </xsl:otherwise>
      </xsl:choose>

    </xsl:when>
    <xsl:otherwise>
      <xsl:value-of select="concat($cache, $_norm)"/>
    </xsl:otherwise>
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

<xsl:template name="str:token-intersection">
  <xsl:param name="left"  select="''"/>
  <xsl:param name="right" select="''"/>
  <xsl:param name="init"  select="true()"/>

  <xsl:variable name="_l" select="normalize-space($left)"/>
  <xsl:variable name="_r" select="normalize-space($right)"/>

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

<xsl:template name="str:nth-token">
  <xsl:param name="string"/>
  <xsl:param name="index" select="1"/>
  <xsl:param name="_cache"/>

  <xsl:variable name="_norm" select="normalize-space($string)"/>
  <xsl:variable name="elements" select="string-length($_norm) - string-length(translate($_norm, ' ', '')) + number($_norm != '')"/>

  <xsl:choose>
    <xsl:when test="$index &lt; $elements"/>
    <xsl:when test="$elements = 1 and $index = 1">
      <xsl:value-of select="$_norm"/>
    </xsl:when>
    <xsl:when test="$index = 1">
      <xsl:value-of select="substring-before($_norm, ' ')"/>
    </xsl:when>
    <xsl:when test="$elements = 2 and $index = 2">
      <xsl:value-of select="substring-after($_norm, ' ')"/>
    </xsl:when>
    <xsl:otherwise>
      <xsl:variable name="half-length" select="floor(string-length($_norm) div 2)"/>
      <xsl:variable name="left-half"   select="substring($_norm, 1, $half-length)"/>
      <xsl:variable name="right-half"  select="substring($_norm, string-length($_norm) div 2)"/>
      <xsl:variable name="left-elems" select="string-length($left-half) - string-length(translate($left-half, ' ', '')) + number($left-half != '')"/>
    </xsl:otherwise>
  </xsl:choose>

</xsl:template>

<!--
    Since it's O(n/2) recursions to find the true centre of the list,
    we assume the tokens are roughly the same length as one another,
    meaning we can just cut the string in half and be reasonably
    confident that we partitioned the sets evenly. however there are
    caveats:

    1) Obviously it will be more likely than not that we will cut
    through one of the tokens, so we need to cut the first piece off
    the right half and glue it back onto the left half.

    1a) If the left half ends with a space or the right half starts
    with a space, we know that this didn't happen. But otherwise...

    2) It is possible that the entire right half of the string
    contains less than one token, i.e., that the last delimiter is in
    the left half. This means we can't just naïvely glue the entire
    right half back onto the left half because that will produce an
    infinite loop.

    3) The first token fragment of the right half is passed into the
    next recursion where it is added to the *end* of the *right* half
    of the subsequent partitioning.

    3a) Note that we can't just move a cut token fragment from the
    left to the right because *that* is O(n).
    
 -->

<xsl:template name="str:sort-tokens">
  <xsl:param name="string"/>
  <xsl:param name="_fragment"     select="''"/><!-- gets attached to right -->
  <xsl:param name="numeric"    select="false()"/>
  <xsl:param name="descending" select="false()"/>
  <xsl:param name="unique"     select="false()"/>

  <xsl:variable name="_norm" select="normalize-space($string)"/>
  <xsl:variable name="elements" select="string-length($_norm) - string-length(translate($_norm, ' ', '')) + number($_norm != '')"/>

  <!--<xsl:message>norm (<xsl:value-of select="$_norm"/>) overhang (<xsl:value-of select="$_fragment"/>)</xsl:message>-->

  <xsl:choose>
    <xsl:when test="$elements = 0">
      <!--<xsl:message>WAT (<xsl:value-of select="concat($_norm, $_fragment)"/>)</xsl:message>-->
    </xsl:when>
    <xsl:when test="$elements = 1">
      <xsl:value-of select="concat($_norm, $_fragment, ' ')"/>
    </xsl:when>
    <xsl:when test="$elements = 2">
      <xsl:variable name="_l" select="substring-before($_norm, ' ')"/>
      <xsl:variable name="_r" select="concat(substring-after($_norm, ' '), $_fragment)"/>
      <!--<xsl:message>yay look at (<xsl:value-of select="$_l"/>) and (<xsl:value-of select="$_r"/>)</xsl:message>-->
      <xsl:choose>
        <xsl:when test="$numeric">
          <xsl:variable name="__l" select="number($_l)"/>
          <xsl:variable name="__r" select="number($_r)"/>
          <xsl:choose>
            <!-- two numbers can have different string representations
                 and still be numerically equal. -->
            <xsl:when test="$unique and $__l = $__r">
              <xsl:value-of select="concat($__l, ' ')"/>
            </xsl:when>
            <xsl:when test="($__l &lt;= $__r) or ($descending and $__l &gt;= $__r)">
              <xsl:value-of select="concat($__l, ' ', $__r, ' ')"/>
            </xsl:when>
            <xsl:otherwise>
              <xsl:value-of select="concat($__r, ' ', $__l, ' ')"/>
            </xsl:otherwise>
          </xsl:choose>
        </xsl:when>
        <xsl:when test="$unique and $_l = $_r">
          <xsl:value-of select="concat($_l, ' ')"/>
        </xsl:when>
        <xsl:when test="($_l &lt;= $_r) or ($descending and $_l &gt;= $_r)">
          <xsl:value-of select="concat($_l, ' ', $_r, ' ')"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="concat($_r, ' ', $_l, ' ')"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:when>
    <xsl:otherwise>
      <xsl:variable name="_lh"  select="substring($_norm, 1, floor(string-length($_norm) div 2) )"/>
      <xsl:variable name="_rh"  select="concat(substring($_norm, string-length($_lh) + 1), $_fragment)"/>

      <xsl:variable name="new-fragment">
        <!--<xsl:message>HUH (<xsl:value-of select="substring($_lh, string-length($_lh))"/>)</xsl:message>-->
        <xsl:if test="substring($_lh, string-length($_lh)) != ' ' and not(starts-with($_rh, ' '))">
          <xsl:choose>
            <xsl:when test="contains($_rh, ' ')">
              <xsl:value-of select="substring-before($_rh, ' ')"/>
            </xsl:when>
            <xsl:otherwise><xsl:value-of select="$_rh"/></xsl:otherwise>
          </xsl:choose>
        </xsl:if>
      </xsl:variable>

      <xsl:variable name="left">
        <xsl:call-template name="str:sort-tokens">
          <xsl:with-param name="string"     select="$_lh"/>
          <xsl:with-param name="_fragment"  select="$new-fragment"/>
          <xsl:with-param name="numeric"    select="$numeric"/>
          <xsl:with-param name="descending" select="$descending"/>
          <xsl:with-param name="unique"     select="$unique"/>
        </xsl:call-template>
      </xsl:variable>

      <xsl:variable name="right">
        <xsl:variable name="_" select="substring($_rh, string-length($new-fragment) + 1)"/>
        <xsl:if test="normalize-space($_) != ''">
          <xsl:call-template name="str:sort-tokens">
            <xsl:with-param name="string"     select="$_"/>
            <xsl:with-param name="numeric"    select="$numeric"/>
            <xsl:with-param name="descending" select="$descending"/>
            <xsl:with-param name="unique"     select="$unique"/>
          </xsl:call-template>
        </xsl:if>
      </xsl:variable>

      <!--<xsl:message>left  (<xsl:value-of select="$left"/>)</xsl:message>
      <xsl:message>right (<xsl:value-of select="$right"/>)</xsl:message>-->

      <xsl:call-template name="str:_merge">
        <xsl:with-param name="left"       select="$left"/>
        <xsl:with-param name="right"      select="$right"/>
        <xsl:with-param name="numeric"    select="$numeric"/>
        <xsl:with-param name="descending" select="$descending"/>
        <xsl:with-param name="unique"     select="$unique"/>
      </xsl:call-template>

    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<xsl:template name="str:_merge">
  <xsl:param name="left"  select="''"/>
  <xsl:param name="right" select="''"/>
  <xsl:param name="numeric"    select="false()"/>
  <xsl:param name="descending" select="false()"/>
  <xsl:param name="unique"     select="false()"/>

  <xsl:variable name="ln" select="normalize-space($left)"/>
  <xsl:variable name="rn" select="normalize-space($right)"/>

  <!--<xsl:message>ln (<xsl:value-of select="$ln"/>) rn (<xsl:value-of select="$rn"/>)</xsl:message>-->


  <xsl:choose>
    <xsl:when test="$ln = '' and $rn = ''"/>
    <xsl:when test="$ln = ''"><xsl:value-of select="concat($rn, ' ')"/></xsl:when>
    <xsl:when test="$rn = ''"><xsl:value-of select="concat($ln, ' ')"/></xsl:when>
    <xsl:otherwise>
      <xsl:variable name="le" select="string-length($ln) - string-length(translate($ln, ' ', '')) + number($ln != '')"/>
      <xsl:variable name="re" select="string-length($rn) - string-length(translate($rn, ' ', '')) + number($rn != '')"/>

      <xsl:variable name="lf">
        <xsl:choose>
          <xsl:when test="$le &gt; 1">
            <xsl:value-of select="substring-before($ln, ' ')"/>
          </xsl:when>
          <xsl:otherwise><xsl:value-of select="$ln"/></xsl:otherwise>
        </xsl:choose>
      </xsl:variable>

      <xsl:variable name="lr" select="substring($ln, string-length($lf) + 2)"/>

      <!--<xsl:message>lf (<xsl:value-of select="$lf"/>) lr (<xsl:value-of select="$lr"/>)</xsl:message>-->

      <xsl:variable name="rf">
        <xsl:choose>
          <xsl:when test="$re &gt; 1">
            <xsl:value-of select="substring-before($rn, ' ')"/>
          </xsl:when>
          <xsl:otherwise><xsl:value-of select="$rn"/></xsl:otherwise>
        </xsl:choose>
      </xsl:variable>

      <xsl:variable name="rr" select="substring($rn, string-length($rf) + 2)"/>

      <!--<xsl:message>rf (<xsl:value-of select="$rf"/>) rr (<xsl:value-of select="$rr"/>)</xsl:message>-->

      <xsl:choose>
        <xsl:when test="$numeric">
          <xsl:message terminate="yes">DO NOT RUN</xsl:message>
          <xsl:variable name="ld" select="number($lf)"/>
          <xsl:variable name="rd" select="number($rf)"/>
        </xsl:when>
        <xsl:when test="$unique and $lf = $rf">
          <!--<xsl:message terminate="yes">DO NOT RUN</xsl:message>-->
          <xsl:value-of select="concat($lf, ' ')"/>
          <xsl:choose>
            <xsl:when test="$le &lt;= 1 and $re &lt;= 1"/>
            <xsl:when test="$le &lt;= 1">
              <xsl:value-of select="concat($rr, ' ')"/>
            </xsl:when>
            <xsl:when test="$re &lt;= 1">
              <xsl:value-of select="concat($lr, ' ')"/>
            </xsl:when>
            <xsl:otherwise>
              <xsl:call-template name="str:_merge">
                <xsl:with-param name="left"       select="$lr"/>
                <xsl:with-param name="right"      select="$rr"/>
                <xsl:with-param name="numeric"    select="$numeric"/>
                <xsl:with-param name="descending" select="$descending"/>
                <xsl:with-param name="unique"     select="$unique"/>
              </xsl:call-template>
            </xsl:otherwise>
          </xsl:choose>
        </xsl:when>
        <xsl:when test="($lf &lt;= $rf) or ($descending and $lf &gt;= $rf)">
          <!--<xsl:message>'<xsl:value-of select="$lf"/>' &lt;= '<xsl:value-of select="$rf"/>'</xsl:message>-->
          <xsl:value-of select="concat($lf, ' ')"/>

          <!-- if that was the last right then just append it
          if it was the last left then just append all the rights -->
 
         <!--
           <xsl:choose>
            <xsl:when test="$le &lt;= 1 and $re &lt;= 1"/>
            <xsl:when test="$le &lt;= 1">
              <xsl:value-of select="concat($rr, ' ')"/>
            </xsl:when>
            <xsl:when test="$re &lt;= 1">
              <xsl:value-of select="concat($lr, ' ')"/>
            </xsl:when>
            <xsl:otherwise>
              <xsl:call-template name="str:_merge">
                <xsl:with-param name="left"       select="$lr"/>
                <xsl:with-param name="right"      select="$rr"/>
                <xsl:with-param name="numeric"    select="$numeric"/>
                <xsl:with-param name="descending" select="$descending"/>
                <xsl:with-param name="unique"     select="$unique"/>
              </xsl:call-template>
            </xsl:otherwise>
          </xsl:choose>-->

          <xsl:call-template name="str:_merge">
            <xsl:with-param name="left"       select="$lr"/>
            <xsl:with-param name="right"      select="$rn"/>
            <xsl:with-param name="numeric"    select="$numeric"/>
            <xsl:with-param name="descending" select="$descending"/>
            <xsl:with-param name="unique"     select="$unique"/>
          </xsl:call-template>
        </xsl:when>
        <xsl:otherwise>
          <!--<xsl:message>'<xsl:value-of select="$lf"/>' &gt;= '<xsl:value-of select="$rf"/>'</xsl:message>-->
          <xsl:value-of select="concat($rf, ' ')"/>
          <xsl:call-template name="str:_merge">
            <xsl:with-param name="left"       select="$ln"/>
            <xsl:with-param name="right"      select="$rr"/>
            <xsl:with-param name="numeric"    select="$numeric"/>
            <xsl:with-param name="descending" select="$descending"/>
            <xsl:with-param name="unique"     select="$unique"/>
          </xsl:call-template>
        </xsl:otherwise>
      </xsl:choose>

    </xsl:otherwise>
  </xsl:choose>

</xsl:template>

<!--
    ### NOW RDFA STUFF ###
-->



</xsl:stylesheet>